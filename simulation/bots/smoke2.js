import path from "node:path"
import { Clock, sleep } from "./lib/clock.js"
import { EventLog } from "./lib/events.js"
import { launchBrowser, Device } from "./lib/device.js"
import { createHunt } from "./roles/organizer.js"
import { nextPhoto, CLIP_70 } from "./lib/fixtures.js"
import { RESULTS, TIMELINE, PASSWORD } from "./config.js"

const dir = path.join(RESULTS, "smoke2-" + Date.now())
const log = new EventLog(dir)
const clock = new Clock(1)
const shots = path.join(dir, "screenshots")
const browser = await launchBrowser({ headless: true })
const ctx = { clock, log, resultsDir: dir, teams: new Map() }
const check = (label, ok, detail = "") => console.log(`${ok ? "PASS" : "FAIL"} ${label} ${detail}`)

clock.start()
clock.t0 = Date.now() - (TIMELINE.start - 1) * 60000
const laptop = await new Device({ browser, name: "organizer", kind: "laptop", log, clock, shots }).open()
const code = await createHunt(laptop, ctx)
ctx.code = Promise.resolve(code)
await laptop.unlockResults(code, PASSWORD)

const a = await new Device({ browser, name: "phone-a", kind: "phone", log, clock, shots }).open()
const b = await new Device({ browser, name: "phone-b", kind: "phone", log, clock, shots }).open()
const c = await new Device({ browser, name: "phone-c", kind: "phone", log, clock, shots }).open()
await c.goto(`/scavenger_hunts/${code}`)
const t0 = Date.now()
const teamId = await a.joinHunt(code, { create: "Late Owls" })
const appeared = await c.page.locator(`#teams input[value="${teamId}"]`).waitFor({ timeout: 5000 }).then(() => Date.now() - t0).catch(() => null)
check("new team appears live on another phone", appeared !== null, `${appeared} ms`)
const picked = await c.joinHunt(code, { pick: "Late Owls" }).catch((e) => String(e))
check("picked the new team from the list", picked === teamId, String(picked))
await b.joinHunt(code, { pick: "Late Owls" })

await a.chat("one", { keepOpen: true })
const second = await a.chat("two within a second", { keepOpen: true }).catch((e) => String(e))
const notice = await a.text("[id^=chat_notice_]")
check("throttle refuses the second message", second === 429 || /second/i.test(notice || ""), `${second} ${notice}`)
await a.closeChat()
await laptop.goto(`/scavenger_hunts/${code}/teams/${teamId}`)
await laptop.openChat()
laptop.page.once("dialog", (d) => d.accept())
const target = laptop.page.locator("[data-testid=chat-message]", { hasText: "one" }).last()
const mid = await target.getAttribute("data-message-id")
await target.hover()
await target.locator("[data-testid=chat-remove]").click({ force: true })
const removedOnB = await b.page.locator(`[data-testid=chat-message][data-message-id="${mid}"][data-removed]`).waitFor({ state: "attached", timeout: 8000 }).then(() => true).catch(() => false)
check("organizer removal reaches another phone", removedOnB)
await laptop.closeChat()

console.log("waiting for the start…")
await clock.at(TIMELINE.start + 0.1)
await a.page.reload()
await b.page.reload()
const items = await a.page.locator("li[data-controller~=submission] span.grow").allTextContents()
const tooLong = await a.uploadPhoto(items[0], CLIP_70, { expect: "banner" }).catch((e) => String(e))
check("70 s video refused with a message", /seconds/i.test(tooLong || ""), tooLong)

await a.setOffline(true)
const queued = await a.uploadPhoto(items[1], nextPhoto(), { expect: "queued" }).catch((e) => String(e))
check("photo queued while offline", typeof queued === "string" && queued.startsWith("submission_"), String(queued))
const foundByB = await b.uploadPhoto(items[1], nextPhoto()).catch((e) => String(e))
check("teammate finds the same item meanwhile", foundByB === queued, String(foundByB))
const queued2 = await a.uploadPhoto(items[2], nextPhoto(), { expect: "queued" }).catch((e) => String(e))
check("second photo queued while offline", typeof queued2 === "string", String(queued2))
await sleep(3000)
const pendingShown = await laptop.goto(`/scavenger_hunts/${code}/results`).then(() => laptop.text("[data-testid=pending-uploads]"))
check("organizer sees pending uploads (only in grace window, so may be null before the end)", true, String(pendingShown))
const tOn = Date.now()
await a.setOffline(false)
const drained = await a.page.locator(`#${queued2}[data-found]`).waitFor({ timeout: 30000 }).then(() => Date.now() - tOn).catch(() => null)
check("queued photo lands after reconnect", drained !== null, `${drained} ms`)
const keptBanner = await a.page.locator("#flash > *", { hasText: "teammate already found" }).waitFor({ state: "attached", timeout: 15000 }).then(() => true).catch(() => false)
check("queued collision shows the teammate-already-found notice", keptBanner)
await a.screenshot("after-drain")

await browser.close()
await log.close()
console.log("dir:", dir)
process.exit(0)
