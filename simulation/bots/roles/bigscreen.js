import { runSchedule } from "../lib/schedule.js"
import { TIMELINE } from "../config.js"

export function bigScreen(device, ctx) {
  const steps = [
    { at: TIMELINE.unlock + 0.2, name: "open-big-screen", run: async () => {
      await device.goto(`/scavenger_hunts/${await ctx.code}/presenter?screen=big`)
      await device.screenshot("big-screen")
      return { progress: await device.text("[data-testid=progress]"), controls: await device.page.locator("button:has-text('Next')").count() }
    } }
  ]
  for (const at of [22, 24.5, 25.5, 27.5, 29.5, 31.5, 33.5]) {
    steps.push({ at, name: "snapshot", run: async () => {
      await device.screenshot("big-screen")
      return { progress: await device.text("[data-testid=progress]"), chat: await device.page.locator("[data-testid=screen-chat]").evaluate((el) => getComputedStyle(el).display === "none" ? "hidden" : el.dataset.screenChatModeValue).catch(() => "none") }
    } })
  }
  return runSchedule(device, ctx.clock, steps)
}
