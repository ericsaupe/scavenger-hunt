import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { sticky: Boolean }

  connect() {
    if (!this.stickyValue) {
      this.timeout = setTimeout(() => this.close(), 5000)
    }
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  close() {
    this.element.classList.add("opacity-0", "-translate-y-2")
    setTimeout(() => this.element.remove(), 300)
  }
}
