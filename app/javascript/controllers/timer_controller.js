import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "container", "countdown" ]
  static values = {
    startsAt: Number,
    endsAt: Number
  }

  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    const now = Date.now()
    const upcoming = this.startsAtValue && this.startsAtValue > now
    const target = upcoming ? this.startsAtValue : this.endsAtValue

    if (upcoming) {
      this.setState("upcoming")
      this.countdownTarget.textContent = `Starts in ${this.format(target - now)}`
      this.toggleFieldsets(true)
    } else if (target && target > now) {
      this.setState("live")
      this.countdownTarget.textContent = `Ends in ${this.format(target - now)}`
      this.toggleFieldsets(false)
    } else if (target) {
      this.setState("ended")
      this.countdownTarget.textContent = "Hunt over. No more submissions."
      this.toggleFieldsets(true)
      clearInterval(this.interval)
    }
  }

  format(distance) {
    const days = Math.floor(distance / 86400000)
    const hours = Math.floor((distance % 86400000) / 3600000)
    const minutes = Math.floor((distance % 3600000) / 60000)
    const seconds = Math.floor((distance % 60000) / 1000)
    const pad = (n) => String(n).padStart(2, "0")
    if (days > 0) {
      return `${days}d ${hours}h ${pad(minutes)}m`
    }
    if (hours > 0) {
      return `${hours}h ${pad(minutes)}m ${pad(seconds)}s`
    }
    return `${minutes}m ${pad(seconds)}s`
  }

  setState(state) {
    this.containerTarget.dataset.state = state
  }

  toggleFieldsets(disabled) {
    document.querySelectorAll("fieldset.submission-fieldset").forEach(fieldset => {
      fieldset.disabled = disabled
    })
  }
}
