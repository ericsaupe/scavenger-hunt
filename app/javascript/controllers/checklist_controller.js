import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "list", "progress", "bar" ]

  connect() {
    this.update()
    this.observer = new MutationObserver(() => this.update())
    this.observer.observe(this.listTarget, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-found"] })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  update() {
    const total = this.listTarget.querySelectorAll("li[data-item]").length
    const found = this.listTarget.querySelectorAll("li[data-found]").length
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = total === found && total > 0 ? `All ${total} found` : `${found} of ${total} found`
    }
    if (this.hasBarTarget) {
      this.barTarget.style.width = total > 0 ? `${Math.round((found / total) * 100)}%` : "0%"
    }
  }
}
