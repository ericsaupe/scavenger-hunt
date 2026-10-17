import fs from "node:fs"
import path from "node:path"
import { runSchedule } from "../lib/schedule.js"
import { sleep } from "../lib/clock.js"
import { TIMELINE, PASSWORD, FLAG_THRESHOLD, TEAMS } from "../config.js"

const HUNT_NAME = "Maple Street Block Party"
const TEMPLATE = "Neighborhood Navigator"

function localStamp(date) {
  const pad = (n) => String(n).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
}

export async function createHunt(device, ctx) {
  const startsAt = new Date(ctx.clock.t0 + TIMELINE.start * 60000)
  const endsAt = new Date(ctx.clock.t0 + TIMELINE.end * 60000)
  return device.act("create-hunt", HUNT_NAME, async () => {
    await device.goto("/scavenger_hunts")
    await device.page.locator("[data-testid=template]", { hasText: TEMPLATE }).first().click()
    await device.page.locator("#hunt_name").waitFor()
    await device.page.fill("#hunt_name", HUNT_NAME)
    for (const [selector, value] of [["#hunt_starts_at", localStamp(startsAt)], ["#hunt_ends_at", localStamp(endsAt)]]) {
      await device.page.locator(selector).evaluate((input, v) => {
        input._flatpickr ? input._flatpickr.setDate(v, true) : (input.value = v)
        input.dispatchEvent(new Event("change", { bubbles: true }))
      }, value)
    }
    await device.page.locator("#hunt_chat_enabled").check({ force: true })
    if (await device.page.locator("#hunt_lock_results").isChecked()) await device.page.locator("#hunt_lock_results").uncheck({ force: true })
    await device.page.fill("#hunt_lock_password", PASSWORD)
    await device.page.fill("#hunt_max_downvotes_to_lose_points", String(FLAG_THRESHOLD))
    await device.screenshot("create-form")
    await Promise.all([
      device.page.waitForURL(/\/scavenger_hunts\/[A-Z0-9]+$/, { timeout: 30000 }),
      device.page.click("button:has-text('Create hunt')")
    ])
    const code = device.page.url().split("/").pop()
    device.say(`created hunt ${code} (${localStamp(startsAt)} to ${localStamp(endsAt)})`)
    await device.screenshot("hunt-created")
    return code
  })
}

export function organizerLaptop(device, ctx) {
  const { clock } = ctx
  const code = () => ctx.code
  const steps = [
    { at: 0.4, name: "print-list", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/print`)
      await device.screenshot("print")
      return await device.text("h1")
    } },
    { at: 1.0, name: "unlock-results", run: async () => {
      const state = await device.unlockResults(await code(), PASSWORD)
      await device.screenshot("results-unlocked")
      return state
    } },
    { at: 1.3, name: "unlock-leaderboard", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/results`)
      const form = device.page.locator("form[action*=unlock_leaderboard]")
      if (!(await form.count())) return "already visible"
      const posted = device.page.waitForResponse((r) => r.url().includes("/unlock_leaderboard"), { timeout: 20000 }).catch(() => null)
      await form.locator("input[name=password]").fill(PASSWORD)
      await form.locator("button:has-text('Unlock leaderboard')").click()
      await posted
      await device.page.waitForLoadState("networkidle").catch(() => {})
      await device.screenshot("leaderboard-unlocked")
      return (await device.page.locator("form[action*=unlock_leaderboard]").count()) ? "still locked" : "unlocked"
    } },
    { at: 2.0, name: "chat", key: "Welcome to Maple Street! Lists unlock at the start time.", run: async () => {
      const blue = await ctx.teamId(TEAMS.blue.name)
      await device.goto(`/scavenger_hunts/${await code()}/teams/${blue}`)
      return device.chat("Welcome to Maple Street! Lists unlock at the start time.", { keepOpen: false })
    } },
    { at: 8.0, name: "chat", key: "Remember: the blue door is on Maple, not Elm.", run: () => device.chat("Remember: the blue door is on Maple, not Elm.", { keepOpen: false }) },
    { at: 10.0, name: "announce", key: "Pizza is here. Grab a slice, we keep going.", run: () => device.chat("Pizza is here. Grab a slice, we keep going.", { announcement: true, keepOpen: false }) },
    { at: 11.0, name: "watch-results", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/results`)
      return await device.text("table")
    } },
    { at: 12.0, name: "chat", key: "Six minutes left, teams.", run: async () => {
      const blue = await ctx.teamId(TEAMS.blue.name)
      await device.goto(`/scavenger_hunts/${await code()}/teams/${blue}`)
      return device.chat("Six minutes left, teams.", { keepOpen: false })
    } },
    { at: 14.0, name: "remove-message", run: async () => {
      await device.openChat()
      device.page.once("dialog", (dialog) => dialog.accept())
      const target = device.page.locator("[data-testid=chat-message]", { hasText: "Jo" }).last()
      const id = await target.getAttribute("data-message-id")
      await target.hover()
      await target.locator("[data-testid=chat-remove]").click({ force: true })
      await device.page.locator(`[data-testid=chat-message][data-message-id="${id}"][data-removed]`).waitFor({ timeout: 10000 })
      await device.closeChat()
      return id
    } },
    { at: 16.0, name: "chat", key: "Two minutes. Upload what you have.", run: () => device.chat("Two minutes. Upload what you have.", { keepOpen: false }) },
    { at: 16.5, name: "watch-results", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/results`)
      return await device.text("table")
    } },
    { at: TIMELINE.unlock, name: "results-after-end", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/results`)
      await device.screenshot("results-after-end")
      return { pending: await device.text("[data-testid=pending-uploads]"), table: await device.text("table") }
    } },
    { at: TIMELINE.show - 0.5, name: "open-big-screen-link", run: async () => {
      return await device.page.locator("a:has-text('Present on a big screen')").getAttribute("href")
    } },
    { at: 28.0, name: "announce-during-show", key: "Three more photos and then the finale.", run: async () => {
      const blue = await ctx.teamId(TEAMS.blue.name)
      await device.goto(`/scavenger_hunts/${await code()}/teams/${blue}`)
      return device.chat("Three more photos and then the finale.", { announcement: true, keepOpen: false })
    } },
    { at: TIMELINE.handoff, name: "take-remote-back", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/presenter`)
      await device.page.click("summary:has-text('Take the remote')")
      await device.page.fill("input[name=password]", PASSWORD)
      await Promise.all([device.page.waitForURL(/\/presenter\/remote/, { timeout: 20000 }), device.page.click("button:has-text('Take it')")])
      await device.screenshot("remote-back")
      return device.page.url()
    } },
    { at: TIMELINE.handoff + 0.5, name: "download-zip", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/results`)
      const download = device.page.waitForEvent("download", { timeout: 120000 }).catch(() => null)
      await device.page.click("a:has-text('Download photos')")
      const file = await download
      if (!file) throw new Error("no download started")
      const target = path.join(ctx.resultsDir, "results.zip")
      await file.saveAs(target)
      const size = fs.statSync(target).size
      device.say(`downloaded results zip, ${size} bytes`)
      return { size }
    } },
    { at: TIMELINE.flipper + 0.3, name: "chat-flag-off-check", run: async () => {
      const blue = await ctx.teamId(TEAMS.blue.name)
      await device.goto(`/scavenger_hunts/${await code()}/teams/${blue}`)
      await sleep(1000)
      return (await device.page.locator("[data-testid=chat-pill]").count()) ? "present" : "absent"
    } },
    { at: TIMELINE.flipper + 0.8, name: "chat-flag-on-check", run: async () => {
      const blue = await ctx.teamId(TEAMS.blue.name)
      await device.goto(`/scavenger_hunts/${await code()}/teams/${blue}`)
      await sleep(1000)
      return (await device.page.locator("[data-testid=chat-pill]").count()) ? "present" : "absent"
    } }
  ]
  return runSchedule(device, clock, steps)
}

export function organizerPhone(device, ctx) {
  const { clock } = ctx
  const code = () => ctx.code
  const remote = (testid) => device.page.locator(`[data-testid=${testid}]`)
  const waitForSlideChange = async (before) => {
    await device.page.waitForFunction((prev) => document.querySelector("[data-testid=progress]")?.textContent.trim() !== prev, before, { timeout: 15000 }).catch(() => null)
    return device.text("[data-testid=progress]")
  }
  const next = async () => {
    const before = await device.text("[data-testid=progress]")
    await device.page.click("button:has-text('Next')")
    return waitForSlideChange(before)
  }
  const steps = [
    { at: TIMELINE.unlock + 0.5, name: "take-remote", run: async () => {
      await device.goto(`/scavenger_hunts/${await code()}/presenter`)
      await device.page.click("summary:has-text('Take the remote')")
      await device.page.fill("input[name=password]", PASSWORD)
      await Promise.all([device.page.waitForURL(/\/presenter\/remote/, { timeout: 20000 }), device.page.click("button:has-text('Take it')")])
      await device.screenshot("remote")
      return await device.text("[data-testid=progress]")
    } }
  ]
  let t = TIMELINE.show + 0.2
  let videoDone = 0
  let jumped = false
  let previousDone = false
  for (let i = 0; i < 34; i++) {
    const at = t
    steps.push({ at, name: "next", run: async () => {
      if (await remote("play").count() && videoDone < 2) {
        videoDone += 1
        await remote("play").click()
        await remote("pause").waitFor({ timeout: 10000 })
        await sleep(6000)
        await remote("pause").click()
        await remote("play").waitFor({ timeout: 10000 })
        await sleep(2000)
        await remote("replay").click()
        await sleep(3000)
        await remote("sound").click()
        await sleep(2000)
        await device.screenshot("video-controls")
      }
      if (at >= 25 && at < 25.4 && !(await remote("screen-chat-switch").isChecked())) {
        await remote("screen-chat-switch").check({ force: true })
        await sleep(1500)
      }
      if (at >= 29 && at < 29.4) {
        await remote("announcements-only-switch").check({ force: true })
        await sleep(1500)
      }
      if (at >= 31 && at < 31.4) {
        await remote("announcements-only-switch").uncheck({ force: true })
        await sleep(1500)
      }
      if (at >= 26.5 && !previousDone) {
        previousDone = true
        const before = await device.text("[data-testid=progress]")
        await device.page.click("button:has-text('Previous')")
        await waitForSlideChange(before)
        await sleep(2000)
      }
      if (at >= 27.2 && !jumped) {
        jumped = true
        await remote("jump-to-item").click()
        await device.page.locator("[data-testid=item-list] button").nth(3).waitFor({ timeout: 5000 })
        await device.screenshot("jump-sheet")
        const before = await device.text("[data-testid=progress]")
        await device.page.locator("[data-testid=item-list] button").nth(3).click()
        return waitForSlideChange(before)
      }
      return next()
    } })
    t += 0.33
    if (t >= TIMELINE.finale - 1.2) break
  }
  steps.push({ at: TIMELINE.finale - 1.0, name: "advance-to-finale", run: async () => {
    for (let i = 0; i < 120; i++) {
      const progress = await device.text("[data-testid=progress]")
      if (progress?.startsWith("Finale")) break
      await next()
      await sleep(400)
    }
    await device.screenshot("finale-remote")
    return await device.text("[data-testid=current-item]")
  } })
  steps.push({ at: TIMELINE.handoff + 0.4, name: "after-handoff", run: async () => {
    await sleep(3000)
    await device.screenshot("after-handoff")
    return { url: device.page.url(), presenting: await device.text("[data-testid=presenting]") }
  } })
  return runSchedule(device, clock, steps)
}
