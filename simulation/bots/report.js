import fs from "node:fs"
import path from "node:path"
import { PUSH, TIMELINE } from "./config.js"

const read = (dir, file) => fs.readFileSync(path.join(dir, file), "utf8")
const readJson = (dir, file) => (fs.existsSync(path.join(dir, file)) ? JSON.parse(read(dir, file)) : null)

function stats(values) {
  if (!values.length) return null
  const sorted = [...values].sort((a, b) => a - b)
  const pick = (q) => sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))]
  return { n: sorted.length, min: sorted[0], median: pick(0.5), p95: pick(0.95), max: sorted[sorted.length - 1] }
}

export function analyze(dir) {
  const events = read(dir, "events.jsonl").trim().split("\n").map((line) => JSON.parse(line))
  const seen = events.filter((e) => e.type === "seen")
  const actions = events.filter((e) => e.type === "action")
  const notes = events.filter((e) => e.type === "note")
  const hunt = readJson(dir, "hunt.json")
  const db = readJson(dir, "db.json")
  const deliveries = readJson(dir, "deliveries.json") || []
  const devices = [...new Set(events.map((e) => e.device))].filter((d) => d !== "runner" && d !== "infra")

  const latencies = {}
  const missing = {}
  const LIVE_WINDOW = 30000
  const record = (surface, key, source, tStart, matcher) => {
    const perDevice = {}
    let later = 0
    for (const device of devices) {
      if (device === source) continue
      const hit = seen.find((e) => e.device === device && matcher(e) && e.t >= tStart - 1500)
      if (!hit) continue
      if (hit.t - tStart <= LIVE_WINDOW) perDevice[device] = hit.t - tStart
      else later += 1
    }
    const values = Object.values(perDevice)
    if (values.length) (latencies[surface] ||= []).push({ key, source, perDevice, later, ...stats(values) })
    return perDevice
  }

  for (const action of actions.filter((a) => (a.name === "chat" || a.name === "announce") && a.ok)) {
    const own = seen.find((e) => e.device === action.device && e.kind === "chat" && e.extra?.text === action.key && e.t >= action.tStart - 500)
    if (!own) { (missing.chat ||= []).push(action.key); continue }
    record("chat", action.key, action.device, action.tStart, (e) => e.kind === "chat" && e.key === own.key)
    if (action.name === "announce") record("pinned", action.key, action.device, action.tStart, (e) => e.kind === "pinned" && e.key === own.key)
    record("screenchat", action.key, action.device, action.tStart, (e) => e.kind === "screenchat" && e.key === own.key)
  }
  for (const action of actions.filter((a) => (a.name === "photo" || a.name === "video" || a.name === "photo-grace") && a.ok && typeof a.detail === "string")) {
    record("found", `${action.device}:${action.key}`, action.device, action.tStart, (e) => e.kind === "found" && e.key === action.detail)
  }
  for (const action of actions.filter((a) => a.name === "join" && a.ok && typeof a.detail === "string")) {
    record("team", action.key, action.device, action.tStart, (e) => e.kind === "team" && e.key === action.detail)
  }
  for (const action of actions.filter((a) => (a.name === "next" || a.name === "take-remote" || a.name === "advance-to-finale") && a.ok && typeof a.detail === "string")) {
    record("slide", action.detail, action.device, action.tStart, (e) => e.kind === "slide" && e.extra === action.detail)
  }
  for (const action of actions.filter((a) => a.name.startsWith("vote-") && a.ok)) {
    record("reaction", `${action.device}:${action.detail}`, action.device, action.tStart, (e) => e.device === "big-screen" && e.kind === "reaction" && e.t >= action.tStart && e.t <= action.tStart + 8000)
  }

  const AUDIENCE = { chat: 14, pinned: 14, found: 2, team: 1, slide: 13, reaction: 1, screenchat: 1 }
  const summary = {}
  for (const [surface, rows] of Object.entries(latencies)) {
    const all = rows.flatMap((r) => Object.values(r.perDevice))
    const audience = AUDIENCE[surface] ?? devices.length - 1
    summary[surface] = { events: rows.length, ...stats(all), audience, over2s: all.filter((v) => v > 2000).length, over5s: all.filter((v) => v > 5000).length, avgLiveReceivers: Number((all.length / rows.length).toFixed(1)) }
  }

  const byDevice = {}
  for (const d of deliveries) {
    const event = d.payload?.tag ? d.payload.tag.split("-")[0] : "unknown"
    ;(byDevice[d.device] ||= []).push({ event, at: d.receivedAt, title: d.payload?.title, error: d.error, vapidValid: d.vapidValid, keyMatches: d.vapidKeyMatches, ttl: d.ttl, urgency: d.urgency })
  }
  const pushExpected = {}
  for (const device of PUSH.all) pushExpected[device] = ["starting_soon", "lead_change", "announcements", "show", "results"]
  for (const device of PUSH.noAnnouncements) pushExpected[device] = ["starting_soon", "lead_change", "show", "results"]
  for (const device of PUSH.never) pushExpected[device] = []
  const pushTable = Object.entries(pushExpected).map(([device, expected]) => {
    const got = (byDevice[device] || []).map((d) => d.event)
    return { device, expected, got, unexpected: got.filter((e) => !expected.includes(e)), missed: expected.filter((e) => !got.includes(e)) }
  })

  const failures = actions.filter((a) => !a.ok).map((a) => ({ device: a.device, name: a.name, key: a.key, error: a.detail }))
  const serverErrors = notes.filter((n) => n.text === "server error").map((n) => n.extra)
  const pageErrors = notes.filter((n) => n.text === "page error" || n.text === "console error").map((n) => ({ device: n.device, ...n.extra }))
  const webLog = fs.existsSync(path.join(dir, "web.log")) ? read(dir, "web.log") : ""
  const completed = [...webLog.matchAll(/Completed (\d{3}) [^\n]* in (\d+)ms/g)].map((m) => ({ status: Number(m[1]), ms: Number(m[2]) }))
  const requestStats = { count: completed.length, fiveHundreds: completed.filter((c) => c.status >= 500).length, ...stats(completed.map((c) => c.ms)) }
  const jobs = db?.jobs || []
  const jobStats = {
    total: jobs.length,
    errored: jobs.filter((j) => j.error).map((j) => ({ klass: j.klass, error: j.error })),
    queueLatencyMs: stats(jobs.filter((j) => j.performed_at && j.scheduled_at).map((j) => Date.parse(j.performed_at) - Date.parse(j.scheduled_at)).filter((v) => v > -1000))
  }
  const statsRows = fs.existsSync(path.join(dir, "stats.csv")) ? read(dir, "stats.csv").trim().split("\n").slice(1).map((l) => l.split(",")) : []
  const containerPeaks = {}
  const toMb = (s) => { const m = /([\d.]+)\s*([KMG]i?B)/.exec(s || ""); if (!m) return 0; const n = parseFloat(m[1]); return m[2].startsWith("G") ? n * 1024 : m[2].startsWith("K") ? n / 1024 : n }
  for (const [, name, cpu, mem] of statsRows) {
    const row = (containerPeaks[name] ||= { peakMemMb: 0, peakCpu: 0, samples: 0 })
    row.peakMemMb = Math.max(row.peakMemMb, toMb(mem))
    row.peakCpu = Math.max(row.peakCpu, parseFloat(cpu) || 0)
    row.samples += 1
  }

  return { hunt, devices, summary, latencies, missing, push: { table: pushTable, deliveries: byDevice }, failures, serverErrors, pageErrors, requestStats, jobStats, containerPeaks, db, actions, notesCount: notes.length }
}

export function writeReport(dir) {
  const report = analyze(dir)
  fs.writeFileSync(path.join(dir, "report.json"), JSON.stringify(report, null, 2))
  const lines = [`# Simulation ${path.basename(dir)}`, "", `Hunt ${report.hunt?.code}, ${report.devices.length} devices.`, "", "## Latency by surface (ms, server request start to DOM on other devices)", "", "| Surface | Events | Live receipts | Avg receivers | min | median | p95 | max | over 2 s | over 5 s |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
  for (const [surface, s] of Object.entries(report.summary)) lines.push(`| ${surface} | ${s.events} | ${s.n} | ${s.avgLiveReceivers} of ${s.audience} | ${s.min} | ${s.median} | ${s.p95} | ${s.max} | ${s.over2s} | ${s.over5s} |`)
  lines.push("", "## Push deliveries", "", "| Device | Expected | Got | Missed | Unexpected |", "| --- | --- | --- | --- | --- |")
  for (const row of report.push.table) lines.push(`| ${row.device} | ${row.expected.join(" ")} | ${row.got.join(" ")} | ${row.missed.join(" ") || "-"} | ${row.unexpected.join(" ") || "-"} |`)
  lines.push("", "## Failed actions", "")
  for (const f of report.failures) lines.push(`- ${f.device} ${f.name} ${f.key ?? ""}: ${String(f.error).slice(0, 200)}`)
  if (!report.failures.length) lines.push("- none")
  lines.push("", `## Requests: ${report.requestStats.count}, 5xx: ${report.requestStats.fiveHundreds}, median ${report.requestStats.median} ms, p95 ${report.requestStats.p95} ms`)
  lines.push("", `## Jobs: ${report.jobStats.total}, errored: ${report.jobStats.errored.length}, queue latency median ${report.jobStats.queueLatencyMs?.median} ms p95 ${report.jobStats.queueLatencyMs?.p95} ms`)
  lines.push("", "## Container peaks", "")
  for (const [name, p] of Object.entries(report.containerPeaks)) lines.push(`- ${name}: ${p.peakMemMb.toFixed(0)} MB, ${p.peakCpu.toFixed(0)}% CPU`)
  lines.push("", `## Page errors: ${report.pageErrors.length}, server 5xx seen by browsers: ${report.serverErrors.length}`)
  fs.writeFileSync(path.join(dir, "summary.md"), lines.join("\n") + "\n")
  return report
}

if (process.argv[1] && process.argv[1].endsWith("report.js") && process.argv[2]) {
  const report = writeReport(process.argv[2])
  console.log(fs.readFileSync(path.join(process.argv[2], "summary.md"), "utf8"))
}
