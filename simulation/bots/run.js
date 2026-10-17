import fs from "node:fs"
import path from "node:path"
import { spawn, execFileSync } from "node:child_process"
import { Clock, sleep } from "./lib/clock.js"
import { EventLog } from "./lib/events.js"
import { launchBrowser, Device } from "./lib/device.js"
import { registerSubscriber, expireSubscriber, deliveries, clearDeliveries } from "./lib/push.js"
import { createHunt, organizerLaptop, organizerPhone } from "./roles/organizer.js"
import { bigScreen } from "./roles/bigscreen.js"
import { phoneRole } from "./roles/phone.js"
import { buildPlans } from "./plans.js"
import { RESULTS, TIMELINE } from "./config.js"
import { writeReport } from "./report.js"

process.on("unhandledRejection", (error) => console.log(`unhandled rejection: ${String(error).split("\n")[0]}`))
process.on("uncaughtException", (error) => console.log(`uncaught exception: ${String(error).split("\n")[0]}`))

const args = new Set(process.argv.slice(2))
const headless = !args.has("--headed")
const composeDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..")
const dc = (...argv) => execFileSync("docker", ["compose", ...argv], { cwd: composeDir, stdio: "pipe" }).toString()

const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
const resultsDir = path.join(RESULTS, stamp)
fs.mkdirSync(resultsDir, { recursive: true })
const log = new EventLog(resultsDir)
const clock = new Clock(1)
const shots = path.join(resultsDir, "screenshots")

let resolveCode
const ctx = {
  clock,
  log,
  resultsDir,
  code: new Promise((resolve) => (resolveCode = resolve)),
  teams: new Map(),
  teamId: async (name) => {
    for (let i = 0; i < 600; i++) {
      if (ctx.teams.has(name)) return ctx.teams.get(name)
      await sleep(500)
    }
    throw new Error(`team ${name} never appeared`)
  }
}

function sampleStats() {
  const file = fs.createWriteStream(path.join(resultsDir, "stats.csv"))
  file.write("t,container,cpu,mem,mem_limit,net_in,net_out\n")
  const child = spawn("docker", ["stats", "--no-stream", "--format", "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}}"])
  const timer = setInterval(() => {
    const sample = spawn("docker", ["stats", "--no-stream", "--format", "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}}"])
    let out = ""
    sample.stdout.on("data", (d) => (out += d))
    sample.on("close", () => {
      const t = Date.now()
      for (const line of out.trim().split("\n").filter(Boolean)) {
        const [name, cpu, mem, net] = line.split(",")
        const [used, limit] = mem.split(" / ")
        const [netIn, netOut] = net.split(" / ")
        file.write(`${t},${name},${cpu},${used},${limit},${netIn},${netOut}\n`)
      }
    })
  }, 5000)
  child.on("close", () => {})
  return () => { clearInterval(timer); file.end() }
}

function infraCue(name, fn) {
  return clock.at(TIMELINE[name] ?? name).then(async () => {
    const tStart = Date.now()
    try {
      const detail = await fn()
      log.action("infra", String(name), null, tStart, Date.now(), true, detail ?? null)
      console.log(`[${clock.stamp()}] infra: ${name} done`)
    } catch (error) {
      log.action("infra", String(name), null, tStart, Date.now(), false, String(error).slice(0, 400))
      console.log(`[${clock.stamp()}] infra: ${name} failed: ${String(error).split("\n")[0]}`)
    }
  })
}

async function main() {
  console.log(`results in ${resultsDir}`)
  await clearDeliveries()
  const browser = await launchBrowser({ headless })
  const stopStats = sampleStats()
  const devices = new Map()
  const make = async (name, kind, push = null) => {
    const device = await new Device({ browser, name, kind, log, clock, shots, push }).open()
    devices.set(name, device)
    return device
  }

  const plans = buildPlans(await itemNames())
  const laptop = await make("organizer", "laptop")
  const organizerPhoneDevice = await make("organizer-phone", "phone")
  const screen = await make("big-screen", "big")
  const phones = []
  for (const plan of plans) {
    const push = plan.push ? await registerSubscriber(plan.name) : null
    if (push) plan.subscription = push
    phones.push({ plan, device: await make(plan.name, "phone", push) })
  }

  clock.start()
  log.note("runner", "clock started", { t0: clock.t0, timeline: TIMELINE })
  const code = await createHunt(laptop, ctx)
  if (!code) throw new Error("hunt creation failed")
  resolveCode(code)
  fs.writeFileSync(path.join(resultsDir, "hunt.json"), JSON.stringify({ code, t0: clock.t0, timeline: TIMELINE }, null, 2))

  const work = [
    organizerLaptop(laptop, ctx),
    organizerPhone(organizerPhoneDevice, ctx),
    bigScreen(screen, ctx),
    ...phones.map(({ plan, device }) => phoneRole(device, ctx, plan)),
    infraCue(9.3, () => dc("restart", "worker")),
    infraCue(27.0, () => dc("restart", "web")),
    infraCue(23.0, async () => {
      const red2 = plans.find((p) => p.name === "red-2")
      await expireSubscriber(red2.subscription.id)
      return red2.subscription.id
    }),
    infraCue(TIMELINE.flipper, () => dc("exec", "-T", "web", "entrypoint", "bin/rails", "runner", "Flipper.disable(:chat); Rails.cache.clear")),
    infraCue(TIMELINE.flipper + 0.5, () => dc("exec", "-T", "web", "entrypoint", "bin/rails", "runner", "Flipper.enable(:chat); Rails.cache.clear"))
  ]
  await Promise.allSettled(work)
  await clock.at(TIMELINE.done)

  stopStats()
  fs.writeFileSync(path.join(resultsDir, "deliveries.json"), JSON.stringify(await deliveries(), null, 2))
  dc("cp", path.join(path.dirname(new URL(import.meta.url).pathname), "db_dump.rb"), "web:/tmp/db_dump.rb")
  fs.writeFileSync(path.join(resultsDir, "db.json"), dc("exec", "-T", "-e", `HUNT_CODE=${code}`, "web", "entrypoint", "bin/rails", "runner", "/tmp/db_dump.rb"))
  for (const service of ["web", "worker", "db", "push", "caddy"]) {
    fs.writeFileSync(path.join(resultsDir, `${service}.log`), dc("logs", "--no-color", "--since", new Date(clock.t0 - 60000).toISOString(), service))
  }
  await browser.close()
  await log.close()
  writeReport(resultsDir)
  console.log("done")
}

async function itemNames() {
  return JSON.parse(dc("exec", "-T", "web", "entrypoint", "bin/rails", "runner", 'puts Templater.templates.find { |t| t[:name] == "Neighborhood Navigator" }[:categories].flat_map { |c| c[:items] }.to_json'))
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
