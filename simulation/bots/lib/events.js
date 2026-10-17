import fs from "node:fs"
import path from "node:path"

export class EventLog {
  constructor(dir) {
    fs.mkdirSync(dir, { recursive: true })
    this.file = path.join(dir, "events.jsonl")
    this.stream = fs.createWriteStream(this.file, { flags: "a" })
    this.events = []
  }

  seen(device, kind, key, t, extra) {
    this.push({ type: "seen", device, kind, key, t, extra })
  }

  action(device, name, key, tStart, tEnd, ok, detail) {
    this.push({ type: "action", device, name, key, tStart, tEnd, ok, detail })
  }

  note(device, text, extra) {
    this.push({ type: "note", device, text, t: Date.now(), extra })
  }

  push(event) {
    this.events.push(event)
    this.stream.write(JSON.stringify(event) + "\n")
  }

  close() {
    return new Promise((resolve) => this.stream.end(resolve))
  }
}
