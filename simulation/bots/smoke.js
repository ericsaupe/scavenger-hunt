import fs from "node:fs"
import path from "node:path"
import { Clock, sleep } from "./lib/clock.js"
import { EventLog } from "./lib/events.js"
import { launchBrowser, Device } from "./lib/device.js"
import { registerSubscriber, deliveries, clearDeliveries } from "./lib/push.js"
import { createHunt } from "./roles/organizer.js"
import { nextPhoto, CLIP_20 } from "./lib/fixtures.js"
import { RESULTS, TIMELINE, PASSWORD } from "./config.js"

const dir = path.join(RESULTS, "smoke-" + Date.now())
const log = new EventLog(dir)
const clock = new Clock(1)
const shots = path.join(dir, "screenshots")
const browser = await launchBrowser({ headless: !process.argv.includes("--headed") })
const ctx = { clock, log, resultsDir: dir, teams: new Map() }
const check = (label, ok, detail = "") => console.log(`${ok ? "PASS" : "FAIL"} ${label} ${detail}`)

await clearDeliveries()
clock.start()
clock.t0 = Date.now() - (TIMELINE.start - 1) * 60000
const laptop = await new Device({ browser, name: "organizer", kind: "laptop", log, clock, shots }).open()
const code = await createHunt(laptop, ctx)
check("hunt created", !!code, code)
ctx.code = Promise.resolve(code)

const push = await registerSubscriber("phone-a")
const phone = await new Device({ browser, name: "phone-a", kind: "phone", log, clock, shots, push }).open()
const teamId = await phone.joinHunt(code, { create: "Smoke Team" })
check("joined team", !!teamId, String(teamId))
const sw = await phone.page.evaluate(() => navigator.serviceWorker.getRegistration().then((r) => (r ? r.scope : null)).catch((e) => "error " + e))
check("service worker registered", typeof sw === "string" && sw.startsWith("https"), sw)

await phone.goto(`/scavenger_hunts/${code}`)
const subscribed = await phone.subscribeToPush({ announcements: true }).catch((e) => String(e))
check("push subscribed", subscribed === 204, String(subscribed))

const phoneB = await new Device({ browser, name: "phone-b", kind: "phone", log, clock, shots }).open()
await phoneB.joinHunt(code, { pick: "Smoke Team" })

const unlocked = await laptop.unlockResults(code, PASSWORD)
check("results unlocked", unlocked === "unlocked", unlocked)

console.log("waiting for the hunt to start…")
await phone.goto(`/scavenger_hunts/${code}/teams/${teamId}`)
await phoneB.goto(`/scavenger_hunts/${code}/teams/${teamId}`)
await clock.at(TIMELINE.start + 0.1)
await phone.page.reload()
const items = await phone.page.locator("li[data-controller~=submission] span.grow").allTextContents()
check("checklist loaded", items.length > 10, `${items.length} items`)

const t = Date.now()
const found = await phone.uploadPhoto(items[0], nextPhoto()).catch((e) => "error " + e)
check("photo upload", typeof found === "string" && found.startsWith("submission_"), `${found} in ${Date.now() - t} ms`)
await sleep(2000)
const seenByB = await phoneB.page.locator(`#${found}[data-found]`).count()
check("teammate sees the find", seenByB === 1)

const tv = Date.now()
const video = await phone.uploadPhoto(items[1], CLIP_20).catch((e) => "error " + e)
check("video upload", typeof video === "string" && video.startsWith("submission_"), `${video} in ${Date.now() - tv} ms`)
const processing = await phone.page.locator(`#${video} [data-testid=processing]`).count()
check("video shows processing", processing === 1)
const playbackReady = await phoneB.page.locator(`#${video}[data-found]:not(:has([data-testid=processing])) [data-video=true]`).waitFor({ timeout: 180000 }).then(() => true).catch(() => false)
check("playback replaces processing on teammate", playbackReady, `${Date.now() - tv} ms`)

const chat = await phone.chat("hello from phone a", { keepOpen: false }).catch((e) => String(e))
check("chat sent", chat === 200, String(chat))
const chatSeen = await phoneB.page.locator("[data-testid=chat-message]", { hasText: "hello from phone a" }).waitFor({ state: "attached", timeout: 5000 }).then(() => true).catch(() => false)
check("chat seen by teammate", chatSeen)
await laptop.goto(`/scavenger_hunts/${code}/teams/${teamId}`)
const ann = await laptop.chat("organizer announcement", { announcement: true, keepOpen: false }).catch((e) => String(e))
check("announcement sent", ann === 200, String(ann))
const pinned = await phone.page.locator("[id^=organizer_card_], [data-testid=chat-pinned]", { hasText: "organizer announcement" }).first().waitFor({ state: "attached", timeout: 5000 }).then(() => true).catch(() => false)
check("announcement pinned on phone", pinned)
await sleep(8000)
const got = await deliveries()
check("push deliveries", got.length >= 1 && got.every((d) => !d.error), JSON.stringify(got.map((d) => [d.device, d.payload?.tag, d.error])))

const screen = await new Device({ browser, name: "big-screen", kind: "big", log, clock, shots }).open()
await screen.goto(`/scavenger_hunts/${code}/presenter?screen=big`)
check("big screen shows a slide", !!(await screen.text("[data-testid=progress]")), await screen.text("[data-testid=progress]"))
await phoneB.goto(`/scavenger_hunts/${code}/presenter`)
const remote = await new Device({ browser, name: "organizer-phone", kind: "phone", log, clock, shots }).open()
await remote.goto(`/scavenger_hunts/${code}/presenter`)
await remote.page.click("summary:has-text('Take the remote')")
await remote.page.fill("input[name=password]", PASSWORD)
await Promise.all([remote.page.waitForURL(/\/presenter\/remote/, { timeout: 20000 }), remote.page.click("button:has-text('Take it')")])
check("took the remote", remote.page.url().includes("/remote"))
const before = await screen.text("[data-testid=progress]")
const tn = Date.now()
await remote.page.click("button:has-text('Next')")
const changed = await screen.page.waitForFunction((prev) => document.querySelector("[data-testid=progress]")?.textContent.trim() !== prev, before, { timeout: 10000 }).then(() => true).catch(() => false)
check("big screen followed next", changed, `${Date.now() - tn} ms, now ${await screen.text("[data-testid=progress]")}`)
const watcherFollowed = await phoneB.page.waitForFunction((prev) => document.querySelector("[data-testid=progress]")?.textContent.trim() !== prev, before, { timeout: 10000 }).then(() => true).catch(() => false)
check("watcher followed next", watcherFollowed, `${Date.now() - tn} ms`)
if (await phoneB.page.locator("[data-testid=vote-menu-love-button]").count()) {
  const tl = Date.now()
  const status = await phoneB.vote("love")
  const reaction = await screen.page.locator("[data-testid=reaction]").first().waitFor({ timeout: 8000 }).then(() => true).catch(() => false)
  check("love reaction on big screen", status === 200 && reaction, `${Date.now() - tl} ms`)
}
if (await remote.page.locator("[data-testid=screen-chat-switch]").count()) {
  await remote.page.locator("[data-testid=screen-chat-switch]").check({ force: true })
  const shown = await screen.page.locator("[data-testid=screen-chat]").waitFor({ state: "visible", timeout: 8000 }).then(() => true).catch(() => false)
  check("chat column appears on big screen", shown)
}
await screen.screenshot("smoke-big")
await remote.screenshot("smoke-remote")
await phoneB.screenshot("smoke-watcher")
await browser.close()
await log.close()
console.log("events:", fs.readFileSync(path.join(dir, "events.jsonl"), "utf8").split("\n").length, "dir:", dir)
process.exit(0)
