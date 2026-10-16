import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.style.setProperty("--drift", `${Math.round(Math.random() * 60 - 30)}px`)
    this.element.style.setProperty("--sway", `${Math.round(Math.random() * 40 - 20)}deg`)
    this.element.addEventListener("animationend", () => this.element.remove(), { once: true })
    this.timer = setTimeout(() => this.element.remove(), 2500)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
