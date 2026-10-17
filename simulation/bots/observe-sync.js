import fs from "node:fs"
import path from "node:path"
import { launchBrowser, Device } from "./lib/device.js"
import { EventLog } from "./lib/events.js"
import { Clock, sleep } from "./lib/clock.js"

const [code, outDir, minutes = "16"] = process.argv.slice(2)
if (!code || !outDir) {
  console.error("usage: node observe-sync.js <HUNT_CODE> <out dir> [minutes]")
  process.exit(1)
}
fs.mkdirSync(outDir, { recursive: true })
const log = new EventLog(outDir)
const clock = new Clock(1)
clock.start()
const browser = await launchBrowser({ headless: true })
const screen = await new Device({ browser, name: "observer-big", kind: "big", log, clock, shots: path.join(outDir, "shots") }).open()
const watcher = await new Device({ browser, name: "observer-phone", kind: "phone", log, clock, shots: path.join(outDir, "shots") }).open()
await screen.goto(`/scavenger_hunts/${code}/presenter?screen=big`)
await watcher.goto(`/scavenger_hunts/${code}/presenter`)
const out = fs.createWriteStream(path.join(outDir, "sync.csv"))
out.write("t,big,phone,match,mismatch_ms\n")
let mismatchSince = null
let last = ""
const deadline = Date.now() + Number(minutes) * 60000
while (Date.now() < deadline) {
  const big = await screen.text("[data-testid=progress]")
  const phone = await watcher.text("[data-testid=progress]")
  const match = big === phone
  if (!match && mismatchSince === null) mismatchSince = Date.now()
  if (match) mismatchSince = null
  const row = `${Date.now()},${JSON.stringify(big)},${JSON.stringify(phone)},${match},${mismatchSince ? Date.now() - mismatchSince : 0}`
  if (row.slice(14) !== last.slice(14)) {
    out.write(row + "\n")
    console.log(`[${clock.stamp()}] big=${big} phone=${phone} ${match ? "" : "MISMATCH " + (Date.now() - mismatchSince) + "ms"}`)
  }
  last = row
  await sleep(1000)
}
out.end()
await browser.close()
await log.close()
