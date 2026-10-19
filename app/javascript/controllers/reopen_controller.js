import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const REFRESH_DELAY_MS = 1000

export default class extends Controller {
  static targets = ["choice", "other", "minutes", "submit", "remaining", "bar", "time"]
  static values = { endsAt: Number, openedAt: Number, now: Number }

  connect() {
    this.timeTargets.forEach((time) => {
      time.textContent = new Date(time.dateTime).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
    })
    if (this.hasRemainingTarget) {
      this.offset = this.nowValue - Date.now()
      this.tick()
      this.interval = setInterval(() => this.tick(), 1000)
    }
  }

  disconnect() {
    clearInterval(this.interval)
    clearTimeout(this.refreshTimer)
  }

  choose() {
    const other = this.otherTarget.checked
    this.minutesTarget.disabled = !other
    if (other) {
      this.minutesTarget.focus()
    }
    this.type()
  }

  type() {
    this.otherTarget.value = this.minutesTarget.value
    const minutes = parseInt(this.choiceTargets.find((choice) => choice.checked)?.value, 10)
    this.submitTarget.textContent = minutes > 0 ? `Reopen for ${minutes} minute${minutes === 1 ? "" : "s"}` : "Reopen"
  }

  tick() {
    const left = Math.max(0, this.endsAtValue - (Date.now() + this.offset))
    const total = this.endsAtValue - this.openedAtValue
    const seconds = Math.ceil(left / 1000)
    this.remainingTarget.textContent = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`
    this.barTarget.style.width = `${total > 0 ? (left / total) * 100 : 0}%`
    if (left === 0) {
      clearInterval(this.interval)
      this.refreshTimer = setTimeout(() => Turbo.visit(window.location.href, { action: "replace" }), REFRESH_DELAY_MS)
    }
  }
}
