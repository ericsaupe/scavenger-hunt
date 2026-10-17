import fs from "node:fs"
import path from "node:path"

const dir = process.argv[2]
const read = (f) => fs.readFileSync(path.join(dir, f), "utf8")
const events = read("events.jsonl").trim().split("\n").map((l) => JSON.parse(l))
const seen = events.filter((e) => e.type === "seen")
const actions = events.filter((e) => e.type === "action")
const notes = events.filter((e) => e.type === "note")
const hunt = JSON.parse(read("hunt.json"))
const db = JSON.parse(read("db.json"))
const deliveries = JSON.parse(read("deliveries.json"))
const t0 = hunt.t0
const minute = (t) => Number(((t - t0) / 60000).toFixed(2))
const firstSeen = (device, kind, pred = () => true, after = 0) => seen.find((e) => e.device === device && e.kind === kind && e.t >= after && pred(e))
const action = (device, name, key) => actions.find((a) => a.device === device && a.name === name && (key === undefined || a.key === key))
const out = {}

const foxJoin = action("fox-1", "join")
const foxSeen = firstSeen("fox-2", "team", (e) => e.key === foxJoin?.detail, foxJoin?.tStart)
out.teamAppearsLive = { fox2SawFoxesMs: foxSeen ? foxSeen.t - foxJoin.tStart : null }

const uploads = actions.filter((a) => ["photo", "video"].includes(a.name) && a.ok && typeof a.detail === "string")
const teammateLatencies = []
for (const u of uploads) {
  const team = u.device.split("-")[0]
  for (const d of ["blue-1", "blue-2", "blue-3", "red-1", "red-2", "red-3", "green-1", "green-2", "owls-1", "owls-2", "fox-1", "fox-2"].filter((d) => d.startsWith(team) && d !== u.device)) {
    const s = firstSeen(d, "found", (e) => e.key === u.detail, u.tStart - 1500)
    if (s) teammateLatencies.push({ from: u.device, to: d, ms: s.t - u.tStart, minute: minute(u.tStart) })
  }
}
const sorted = teammateLatencies.map((x) => x.ms).sort((a, b) => a - b)
out.teammateFound = { n: sorted.length, median: sorted[Math.floor(sorted.length / 2)], p95: sorted[Math.floor(sorted.length * 0.95)], max: sorted.at(-1), over2s: teammateLatencies.filter((x) => x.ms > 2000) }

out.retake = { blue2: action("blue-2", "photo-retake")?.detail }
out.queuedCollision = { red3Queued: action("red-3", "photo-offline-collision")?.detail, keptBanner: firstSeen("red-3", "banner", (e) => /teammate already found/i.test(e.key)) ? minute(firstSeen("red-3", "banner", (e) => /teammate already found/i.test(e.key)).t) : null, red1FoundSame: action("red-1", "photo", "For Sale Sign")?.detail }

out.videos = actions.filter((a) => a.name === "video" && a.ok).map((v) => {
  const processing = firstSeen("blue-1", "processing", (e) => e.key === v.detail, v.tStart - 1500)
  const playback = firstSeen("blue-1", "playback", (e) => e.key === v.detail, v.tStart)
  return { item: v.key, uploadMs: v.tEnd - v.tStart, processingSeenByTeammateMs: processing ? processing.t - v.tStart : null, playbackSeenByTeammateMs: playback ? playback.t - v.tStart : null, dbPlayback: db.submissions.find((s) => `submission_${s.id}` === v.detail)?.playback }
})
out.videoTooLong = action("blue-3", "video-too-long")?.detail?.replace(/\s+/g, " ").trim()

const red3Online = notes.find((n) => n.device === "red-3" && n.text === "back online")
const red3Found = firstSeen("red-3", "found", (e) => e.key === out.queuedCollision.red3Queued, red3Online?.t)
out.offlineQueue = { queuedAt: minute(action("red-3", "photo-offline-collision")?.tStart), onlineAt: red3Online ? minute(red3Online.t) : null, foundAfterOnlineMs: red3Found && red3Online ? red3Found.t - red3Online.t : null, organizerSawPending: seen.filter((e) => e.device === "organizer" && e.kind === "pending-uploads").map((e) => [minute(e.t), e.key]) }
const green2Online = notes.find((n) => n.device === "green-2" && n.text === "back online")
const graceKey = action("green-2", "photo-grace")?.detail
const graceFound = firstSeen("green-2", "found", (e) => e.key === graceKey, green2Online?.t)
out.graceWindow = { queuedAt: minute(action("green-2", "photo-grace")?.tStart), onlineAt: green2Online ? minute(green2Online.t) : null, acceptedAfterOnlineMs: graceFound && green2Online ? graceFound.t - green2Online.t : null, dbAccepted: db.submissions.some((s) => `submission_${s.id}` === graceKey), afterEndRejected: action("green-1", "photo-after-end")?.detail?.replace(/\s+/g, " ").trim() }

out.results = { peekLocked: action("blue-1", "peek-results")?.detail, unlock: action("organizer", "unlock-results")?.detail, leaderboard: action("organizer", "unlock-leaderboard")?.detail, liveScoreUpdatesSeenByOrganizer: seen.filter((e) => e.device === "organizer" && e.kind === "score").length, finalTable: db.teams.map((t) => [t.name, t.found, t.score]), denied: db.submissions.filter((s) => s.denied).map((s) => [s.item, s.team, s.flags]), zipBytes: fs.existsSync(path.join(dir, "results.zip")) ? fs.statSync(path.join(dir, "results.zip")).size : null }

const chatActions = actions.filter((a) => (a.name === "chat" || a.name === "announce"))
out.chat = { sent: chatActions.filter((a) => a.ok).length, failed: chatActions.filter((a) => !a.ok).map((a) => [a.device, a.name, minute(a.tStart)]), throttled: actions.find((a) => a.key === "second within a second")?.detail, throttleNotice: firstSeen("owls-1", "chat-notice")?.key, dbMessages: db.messages.length, announcements: db.messages.filter((m) => m.announcement).length, pinnedSeenOnDevices: new Set(seen.filter((e) => e.kind === "pinned").map((e) => e.device)).size, removedSeenOnDevices: new Set(seen.filter((e) => e.kind === "removed").map((e) => e.device)).size, unreadBadgesSeen: seen.filter((e) => e.kind === "unread").length, flagOff: action("organizer", "chat-flag-off-check")?.detail, flagOn: action("organizer", "chat-flag-on-check")?.detail }

const byEvent = {}
for (const d of deliveries) (byEvent[d.payload?.tag?.split("-")[0]] ||= []).push(d)
const msgAnnounce = db.messages.find((m) => m.announcement)
const takeRemote = action("organizer-phone", "take-remote")
out.push = {
  deliveries: deliveries.length,
  errors: deliveries.filter((d) => d.error).length,
  allVapidValid: deliveries.every((d) => d.vapidValid && d.vapidKeyMatches),
  perEvent: Object.fromEntries(Object.entries(byEvent).map(([k, v]) => [k, { count: v.length, devices: v.map((d) => d.device), at: [...new Set(v.map((d) => minute(Date.parse(d.receivedAt))))] }])),
  announcementDelayMs: msgAnnounce && byEvent.announcements ? Date.parse(byEvent.announcements[0].receivedAt) - Date.parse(msgAnnounce.created_at) : null,
  showDelayMs: takeRemote && byEvent.show ? Date.parse(byEvent.show[0].receivedAt) - takeRemote.tStart : null,
  resultsReadyMinutesAfterEnd: byEvent.results ? ((Date.parse(byEvent.results[0].receivedAt) - Date.parse(db.hunt.ends_at)) / 60000).toFixed(2) : null,
  leadChangeMinutes: byEvent.lead_change ? [...new Set(byEvent.lead_change.map((d) => minute(Date.parse(d.receivedAt))))] : [],
  subscriptionsLeft: db.push_subscriptions.length,
  expiredDeviceGone: !db.push_subscriptions.some((p) => p.endpoint.includes("red-2"))
}

const nexts = actions.filter((a) => a.name === "next" && a.ok && typeof a.detail === "string" && minute(a.tStart) > 21.4)
const watchers = ["big-screen", "blue-1", "blue-2", "blue-3", "red-1", "red-2", "red-3", "green-1", "green-2", "owls-1", "owls-2", "fox-1", "fox-2"]
const slideLat = []
const perSlide = []
let prev = null
for (const a of nexts) {
  if (a.detail === prev) continue
  prev = a.detail
  const lat = {}
  for (const w of watchers) {
    const s = firstSeen(w, "slide", (e) => e.extra === a.detail, a.tStart - 1500)
    if (s && s.t - a.tStart <= 30000) lat[w] = s.t - a.tStart
  }
  perSlide.push({ minute: minute(a.tStart), slide: a.detail, received: Object.keys(lat).length, max: Math.max(...Object.values(lat), 0), median: Object.values(lat).sort((x, y) => x - y)[Math.floor(Object.values(lat).length / 2)] })
  slideLat.push(...Object.values(lat))
}
const sl = slideLat.sort((a, b) => a - b)
out.slides = { changes: perSlide.length, receipts: sl.length, median: sl[Math.floor(sl.length / 2)], p95: sl[Math.floor(sl.length * 0.95)], max: sl.at(-1), incomplete: perSlide.filter((p) => p.received < 13), restartWindow: perSlide.filter((p) => p.minute >= 26.8 && p.minute <= 28.5) }
out.bigScreen = { openResult: action("big-screen", "open-big-screen")?.detail, playbackStates: seen.filter((e) => e.device === "big-screen" && e.kind === "playback-state").map((e) => [minute(e.t), e.key]), reactionsSeen: seen.filter((e) => e.device === "big-screen" && e.kind === "reaction").length, screenChatModes: seen.filter((e) => e.device === "big-screen" && e.kind === "screenchat-mode").map((e) => [minute(e.t), e.key]), finaleSeenOn: new Set(seen.filter((e) => e.kind === "finale").map((e) => e.device)).size, screenChatMessages: seen.filter((e) => e.device === "big-screen" && e.kind === "screenchat").length }
const reactions = actions.filter((a) => a.name.startsWith("vote-") && a.ok)
const reactionLat = reactions.map((a) => { const r = seen.find((e) => e.device === "big-screen" && e.kind === "reaction" && e.t >= a.tStart && e.t <= a.tStart + 8000); return r ? r.t - a.tStart : null }).filter((v) => v !== null).sort((a, b) => a - b)
out.reactions = { votes: reactions.length, failed: actions.filter((a) => a.name.startsWith("vote-") && !a.ok).map((a) => [a.device, minute(a.tStart)]), matchedOnBigScreen: reactionLat.length, median: reactionLat[Math.floor(reactionLat.length / 2)], max: reactionLat.at(-1), flagsOnSlide: seen.filter((e) => e.device === "big-screen" && e.kind === "flags").map((e) => e.key).filter((k) => /[1-9] of 3/.test(k)) }
out.remote = { takeRemote: takeRemote?.detail, jump: actions.find((a) => a.device === "organizer-phone" && a.name === "next" && minute(a.tStart) >= 27.2 && minute(a.tStart) < 27.6)?.detail, finale: action("organizer-phone", "advance-to-finale")?.detail, afterHandoff: action("organizer-phone", "after-handoff")?.detail, laptopTookBack: action("organizer", "take-remote-back")?.detail, browse: [action("owls-2", "browse-back")?.detail, action("owls-2", "back-to-live")?.detail], livePills: [...new Set(seen.filter((e) => e.device === "owls-2" && e.kind === "live-pill").map((e) => e.key))] }
out.errors = { failedActions: actions.filter((a) => !a.ok).map((a) => [a.device, a.name, minute(a.tStart), String(a.detail).split("\n")[0].slice(0, 120)]), serverErrorsSeenByBrowsers: notes.filter((n) => n.text === "server error").map((n) => [n.device, minute(n.t), n.extra.status, n.extra.url.replace(/^https:\/\/www\.scavengerhunt\.party/, "")]), consoleErrorKinds: Object.entries(notes.filter((n) => n.text === "console error" || n.text === "page error").reduce((acc, n) => { const k = n.extra.text.replace(/https?:\S+/g, "URL").slice(0, 90); acc[k] = (acc[k] || 0) + 1; return acc }, {})) }
out.jobs = { total: db.jobs.length, byClass: db.jobs.reduce((acc, j) => { acc[j.klass] = (acc[j.klass] || 0) + 1; return acc }, {}), errored: db.jobs.filter((j) => j.error).length, transcodes: db.jobs.filter((j) => j.klass === "TranscodeVideoJob").map((j) => [j.scheduled_at?.slice(11, 19), j.performed_at?.slice(11, 19), j.finished_at?.slice(11, 19), j.error]) }
out.cableMessages = db.cable_messages
fs.writeFileSync(path.join(dir, "checklist.json"), JSON.stringify(out, null, 2))
console.log(JSON.stringify(out, null, 1))
