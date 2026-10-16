import { Controller } from "@hotwired/stimulus"
import confetti from "canvas-confetti"

const DURATION = 3000
const INTERVAL = 250
const COLORS = ["#ffb703", "#d7263d", "#2452e0", "#ffffff", "#1f9d55"]

export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return
    }
    const end = Date.now() + DURATION
    const burst = () => {
      const options = { particleCount: 24, spread: 55, startVelocity: 55, ticks: 220, colors: COLORS }
      confetti({ ...options, angle: 60, origin: { x: 0, y: 1 } })
      confetti({ ...options, angle: 120, origin: { x: 1, y: 1 } })
      if (Date.now() < end) {
        this.timer = setTimeout(burst, INTERVAL)
      }
    }
    burst()
  }

  disconnect() {
    clearTimeout(this.timer)
    confetti.reset()
  }
}
