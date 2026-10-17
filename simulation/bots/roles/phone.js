import { runSchedule } from "../lib/schedule.js"
import { nextPhoto, CLIP_20, CLIP_70 } from "../lib/fixtures.js"
import { TIMELINE, PASSWORD } from "../config.js"
import { sleep } from "../lib/clock.js"

export function phoneRole(device, ctx, plan) {
  const { clock } = ctx
  const steps = []

  steps.push({
    at: plan.joinAt,
    name: "join",
    key: plan.team.name,
    run: async () => {
      const code = await ctx.code
      if (plan.watchTeamsFrom !== undefined) {
        await device.goto(`/scavenger_hunts/${code}`)
        await clock.at(plan.pickAt)
      }
      const teamId = await device.joinHunt(code, plan.create ? { create: plan.team.name } : { pick: plan.team.name })
      device.say(`joined ${plan.team.name} as team ${teamId}`)
      ctx.teams.set(plan.team.name, teamId)
      await device.screenshot("checklist")
      return `team_${teamId}`
    }
  })

  if (plan.push) {
    steps.push({
      at: plan.joinAt + 0.15,
      name: "push-subscribe",
      key: plan.push,
      run: async () => {
        const code = await ctx.code
        await device.goto(`/scavenger_hunts/${code}`)
        const status = await device.subscribeToPush({ announcements: plan.push === "all" })
        await device.goto(`/scavenger_hunts/${code}/teams/${device.teamId}`)
        return status
      }
    })
  }

  if (plan.resultsPeekAt !== undefined) {
    steps.push({
      at: plan.resultsPeekAt,
      name: "peek-results",
      run: async () => {
        const code = await ctx.code
        await device.goto(`/scavenger_hunts/${code}/results`)
        const locked = await device.page.locator("text=Results are not yet available").count()
        await device.screenshot("results-peek")
        await device.goto(`/scavenger_hunts/${code}/teams/${device.teamId}`)
        return locked ? "locked" : "open"
      }
    })
  }

  for (const upload of plan.uploads) {
    steps.push({
      at: upload.at,
      name: upload.kind || "photo",
      key: upload.item,
      run: async () => {
        await device.page.locator("li[data-controller~=submission]").first().waitFor({ timeout: 30000 })
        const file = upload.file || nextPhoto()
        const expect = upload.expect || "found"
        const result = await device.uploadPhoto(upload.item, file, { expect })
        device.say(`${upload.kind || "photo"} for ${upload.item}: ${expect} (${result})`)
        return result
      }
    })
  }

  for (const message of plan.chat) {
    steps.push({
      at: message.at,
      name: message.announcement ? "announce" : "chat",
      key: message.text,
      run: async () => {
        const status = await device.chat(message.text, { announcement: !!message.announcement, keepOpen: !!message.keepOpen })
        if (message.keepOpen === false || message.keepOpen === undefined) await device.closeChat()
        return status
      }
    })
  }

  for (const window of plan.offline || []) {
    steps.push({ at: window.from, name: "offline", run: () => device.setOffline(true) })
    steps.push({ at: window.to, name: "online", run: async () => {
      await device.setOffline(false)
      await sleep(15000)
      await device.screenshot("after-reconnect")
    } })
  }

  steps.push({
    at: plan.watchAt ?? TIMELINE.show + 0.5,
    name: "watch",
    run: async () => {
      const code = await ctx.code
      await device.goto(`/scavenger_hunts/${code}/presenter`)
      await device.screenshot("watching")
      return await device.text("[data-testid=progress]")
    }
  })

  for (const vote of plan.votes || []) {
    steps.push({
      at: vote.at,
      name: `vote-${vote.value}`,
      run: async () => {
        await device.closeChat()
        const slide = await device.page.locator("#current_slide [data-print]").first().getAttribute("id").catch(() => null)
        const status = await device.vote(vote.value)
        return `${slide}:${status}`
      }
    })
  }

  if (plan.browse) {
    steps.push({
      at: plan.browse.at,
      name: "browse-back",
      run: async () => {
        await device.closeChat()
        await device.page.click("a[aria-label='Previous slide']")
        await device.page.locator("[data-testid=live-pill]", { hasText: "Browsing" }).waitFor({ timeout: 10000 })
        await device.page.click("a[aria-label='Previous slide']")
        await sleep(1500)
        await device.screenshot("browsing")
        return await device.text("[data-testid=progress]")
      }
    })
    steps.push({
      at: plan.browse.backAt,
      name: "back-to-live",
      run: async () => {
        await device.page.click("[data-testid=back-to-live]")
        await device.page.locator("[data-testid=live-pill]", { hasText: "Live" }).waitFor({ timeout: 10000 })
        return await device.text("[data-testid=progress]")
      }
    })
  }

  if (plan.takeRemoteAt) {
    steps.push({
      at: plan.takeRemoteAt,
      name: "take-remote",
      run: async () => {
        const code = await ctx.code
        await device.goto(`/scavenger_hunts/${code}/presenter`)
        await device.page.click("summary:has-text('Take the remote')")
        await device.page.fill("input[name=password]", PASSWORD)
        await Promise.all([
          device.page.waitForURL(/\/presenter\/remote/, { timeout: 20000 }),
          device.page.click("button:has-text('Take it')")
        ])
        await device.screenshot("remote")
        return device.page.url()
      }
    })
  }

  steps.push({
    at: TIMELINE.done - 0.5,
    name: "final-screenshot",
    run: async () => {
      await device.screenshot("final")
      return device.page.url()
    }
  })

  return runSchedule(device, clock, steps)
}

export { CLIP_20, CLIP_70 }
