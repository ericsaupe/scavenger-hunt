import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const SWIPE_DISTANCE = 60

export default class extends Controller {
  static values = {
    nextUrl: String,
    previousUrl: String,
  }

  connect() {
    this.onTouchStart = (event) => {
      if (event.target.closest("[role='dialog']")) {
        this.start = null
        return
      }
      const touch = event.changedTouches[0]
      this.start = { x: touch.clientX, y: touch.clientY }
    }
    this.onTouchEnd = (event) => {
      if (!this.start) {
        return
      }
      const touch = event.changedTouches[0]
      const dx = touch.clientX - this.start.x
      const dy = touch.clientY - this.start.y
      this.start = null
      if (Math.abs(dx) < SWIPE_DISTANCE || Math.abs(dy) > Math.abs(dx)) {
        return
      }
      this.visit(dx < 0 ? this.nextUrlValue : this.previousUrlValue)
    }
    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.element.addEventListener("touchend", this.onTouchEnd, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchend", this.onTouchEnd)
  }

  visit(url) {
    if (url) {
      Turbo.visit(url, { action: "replace" })
    }
  }
}
