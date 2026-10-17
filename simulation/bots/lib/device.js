import fs from "node:fs"
import path from "node:path"
import { chromium } from "playwright"
import { BASE_URL, HOSTS, PHONE, LAPTOP, BIG_SCREEN, CHAT_NAMES } from "../config.js"
import { OBSERVER_SCRIPT } from "./observe.js"
import { pushStubScript } from "./push.js"

const PROFILES = { phone: PHONE, laptop: LAPTOP, big: BIG_SCREEN }

export async function launchBrowser({ headless = true } = {}) {
  return chromium.launch({
    channel: "chrome",
    headless,
    args: [
      `--host-resolver-rules=${HOSTS.map((host) => `MAP ${host} 127.0.0.1`).join(", ")}`,
      "--ignore-certificate-errors",
      "--autoplay-policy=no-user-gesture-required",
      "--disable-site-isolation-trials"
    ]
  })
}

export class Device {
  constructor({ browser, name, kind, log, clock, shots, push = null }) {
    this.browser = browser
    this.name = name
    this.kind = kind
    this.log = log
    this.clock = clock
    this.shots = shots
    this.push = push
    this.chatName = CHAT_NAMES[name] || name
  }

  async open() {
    this.context = await this.browser.newContext({
      ...PROFILES[this.kind],
      baseURL: BASE_URL,
      ignoreHTTPSErrors: true,
      acceptDownloads: true,
      serviceWorkers: "allow",
      locale: "en-US"
    })
    await this.context.exposeFunction("__simSeen", (kind, key, t, extra) => this.log.seen(this.name, kind, key, t, extra))
    if (this.push) await this.context.addInitScript(pushStubScript(this.push))
    await this.context.addInitScript(OBSERVER_SCRIPT)
    this.page = await this.context.newPage()
    this.page.on("console", (message) => {
      if (message.type() === "error") this.log.note(this.name, "console error", { text: message.text().slice(0, 300) })
    })
    this.page.on("pageerror", (error) => this.log.note(this.name, "page error", { text: String(error).slice(0, 300) }))
    this.page.on("response", (response) => {
      if (response.status() >= 500) this.log.note(this.name, "server error", { url: response.url(), status: response.status() })
    })
    return this
  }

  async close() {
    await this.context?.close().catch(() => {})
  }

  say(text, extra) {
    console.log(`[${this.clock.stamp()}] ${this.name}: ${text}`)
    this.log.note(this.name, text, extra)
  }

  async act(name, key, fn) {
    const tStart = Date.now()
    try {
      const detail = await fn()
      this.log.action(this.name, name, key, tStart, Date.now(), true, detail ?? null)
      return detail
    } catch (error) {
      this.log.action(this.name, name, key, tStart, Date.now(), false, String(error).slice(0, 400))
      console.log(`[${this.clock.stamp()}] ${this.name}: ${name} failed: ${String(error).split("\n")[0]}`)
      await this.screenshot(`fail-${name}`)
      return null
    }
  }

  async goto(pathname) {
    await this.page.goto(pathname, { waitUntil: "load" })
    await this.page.waitForLoadState("networkidle").catch(() => {})
  }

  async screenshot(label) {
    const file = path.join(this.shots, `${this.clock.stamp().padStart(6, "0")}-${this.name}-${label}.png`)
    fs.mkdirSync(this.shots, { recursive: true })
    await this.page.screenshot({ path: file, fullPage: false }).catch(() => {})
    return file
  }

  async setOffline(offline) {
    await this.context.setOffline(offline)
    if (!offline) await this.page.evaluate(() => window.dispatchEvent(new Event("online")))
    this.say(offline ? "went offline" : "back online")
  }

  async joinHunt(code, { create = null, pick = null }) {
    await this.goto(`/scavenger_hunts/${code}`)
    if (create) {
      await this.page.fill("input[name=name]", create)
    } else {
      await this.page.locator("#teams label", { hasText: pick }).first().click()
    }
    await Promise.all([
      this.page.waitForURL(/\/teams\/\d+/),
      this.page.click("button[form=team_form]")
    ])
    this.teamId = Number(this.page.url().match(/\/teams\/(\d+)/)[1])
    return this.teamId
  }

  itemRow(itemName) {
    return this.page.locator("li[data-controller~=submission]").filter({ has: this.page.locator(`xpath=.//span[normalize-space()=${JSON.stringify(itemName)}]`) }).first()
  }

  async uploadPhoto(itemName, file, { expect = "found" } = {}) {
    const row = this.itemRow(itemName)
    const id = await row.getAttribute("id")
    await row.locator("input[type=file]").setInputFiles(file)
    if (expect === "found") {
      await this.page.locator(`#${id}[data-found]`).waitFor({ timeout: 90000 })
    } else if (expect === "queued") {
      await this.page.locator(`#${id} [data-testid=queued-badge]`).waitFor({ timeout: 30000 })
    } else if (expect === "banner") {
      await this.page.locator("#flash > *").first().waitFor({ timeout: 30000 })
      return await this.page.locator("#flash > *").first().textContent()
    }
    return id
  }

  async openChat() {
    const sheet = this.page.locator("[data-testid=chat-sheet]")
    if (!(await sheet.evaluate((el) => el.classList.contains("modal-open"))).valueOf()) {
      await this.page.click("[data-testid=chat-pill]")
    }
    const nameForm = this.page.locator("[data-chat-target=nameForm]")
    if (await nameForm.isVisible()) {
      await nameForm.locator("input[data-chat-target=nameInput]").fill(this.chatName)
      await nameForm.locator("button").click()
      await this.page.locator("[data-chat-target=input]").waitFor()
    }
  }

  async closeChat() {
    const sheet = this.page.locator("[data-testid=chat-sheet]")
    if (await sheet.count() && (await sheet.evaluate((el) => el.classList.contains("modal-open")))) {
      await this.page.keyboard.press("Escape").catch(() => {})
      await this.page.waitForFunction(() => !document.querySelector("[data-testid=chat-sheet]")?.classList.contains("modal-open"), null, { timeout: 3000 }).catch(() => {})
    }
  }

  async unlockResults(code, password) {
    await this.goto(`/scavenger_hunts/${code}/results`)
    const posted = this.page.waitForResponse((r) => r.url().includes("/unlock_results"), { timeout: 20000 }).catch(() => null)
    await this.page.fill("input[name=password]", password)
    await this.page.click("button:has-text('Unlock results')")
    await posted
    await this.page.waitForLoadState("networkidle").catch(() => {})
    await this.page.locator("text=Results are not yet available").waitFor({ state: "detached", timeout: 10000 }).catch(() => {})
    return (await this.page.locator("text=Results are not yet available").count()) === 0 ? "unlocked" : "still locked"
  }

  async chat(text, { announcement = false, keepOpen = true } = {}) {
    await this.openChat()
    const toggle = this.page.locator("[data-testid=chat-announcement-toggle]")
    if (announcement) {
      if ((await toggle.getAttribute("aria-pressed")) !== "true") await toggle.click()
    } else if (await toggle.count()) {
      if ((await toggle.getAttribute("aria-pressed")) === "true") await toggle.click()
    }
    const input = this.page.locator("[data-chat-target=input]")
    await input.fill(text)
    const response = this.page.waitForResponse((r) => r.url().includes("/messages") && r.request().method() === "POST", { timeout: 15000 }).catch(() => null)
    await input.press("Enter")
    const status = (await response)?.status() ?? "no response"
    if (!keepOpen) await this.closeChat()
    return status
  }

  async subscribeToPush({ announcements = true } = {}) {
    await this.page.locator("[data-testid=push-prompt]:not([hidden])").waitFor({ timeout: 15000 })
    const saved = this.page.waitForResponse((r) => r.url().includes("/push_subscription") && r.request().method() === "POST", { timeout: 15000 }).catch(() => null)
    await this.page.click("[data-testid=push-prompt] button:has-text('Allow')")
    const status = (await saved)?.status() ?? "no response"
    if (!announcements) {
      const box = this.page.locator("#notify_announcements")
      await box.waitFor({ timeout: 10000 })
      const patched = this.page.waitForResponse((r) => r.url().includes("/push_subscription") && r.request().method() === "PATCH", { timeout: 15000 }).catch(() => null)
      await box.uncheck({ force: true })
      await patched
    }
    return status
  }

  async vote(value) {
    const button = this.page.locator(`[data-testid=vote-menu-${value}-button]`).first()
    const response = this.page.waitForResponse((r) => r.url().includes("/votes") && r.request().method() === "POST", { timeout: 15000 }).catch(() => null)
    await button.click()
    return (await response)?.status() ?? "no response"
  }

  text(selector) {
    return this.page.locator(selector).first().textContent().then((t) => t.replace(/\s+/g, " ").trim()).catch(() => null)
  }
}
