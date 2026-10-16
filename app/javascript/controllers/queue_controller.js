import { Controller } from "@hotwired/stimulus"
import { count, entries, onChange } from "../uploads/queue"
import { drain, restoreRefusals } from "../uploads/drain"
import { showQueued } from "../uploads/pending"

export default class extends Controller {
  static values = { teamId: Number, reportUrl: String }

  connect() {
    this.reported = 0
    this.onOnline = () => this.drain()
    this.onVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        this.drain()
      }
    }
    this.onMessage = (event) => {
      if (event.data?.type === "drain-queue") {
        this.drain()
      }
    }
    this.stopWatching = onChange(() => this.report())

    window.addEventListener("online", this.onOnline)
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    navigator.serviceWorker?.addEventListener("message", this.onMessage)

    this.restore().then(() => this.drain())
  }

  disconnect() {
    window.removeEventListener("online", this.onOnline)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    navigator.serviceWorker?.removeEventListener("message", this.onMessage)
    this.stopWatching()
  }

  async restore() {
    const queued = await entries(this.teamIdValue)
    queued.forEach((entry) => {
      const row = document.getElementById(`submission_${entry.submissionId}`)
      if (row && !row.dataset.found && !row.dataset.uploading) {
        showQueued(row, entry.file)
      }
    })
    restoreRefusals()
    await this.report(queued.length)
  }

  drain() {
    return drain().then(() => this.report())
  }

  async report(pending) {
    if (!navigator.onLine || !this.hasReportUrlValue) {
      return
    }
    const total = pending ?? await count(this.teamIdValue)
    if (total === 0 && this.reported === 0) {
      return
    }
    this.reported = total
    await fetch(this.reportUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ count: total }),
      keepalive: true
    }).catch(() => {})
  }
}
