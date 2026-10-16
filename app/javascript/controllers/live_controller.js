import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { interval: Number }

  connect() {
    this.lostConnection = false
    this.source = this.element.querySelector("turbo-cable-stream-source")
    this.observer = new MutationObserver(() => this.connectionChanged())
    if (this.source) {
      this.observer.observe(this.source, { attributes: true, attributeFilter: ["connected"] })
    }
    this.onVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        this.refresh()
      }
    }
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    if (this.intervalValue > 0) {
      this.timer = setInterval(() => this.refresh(), this.intervalValue)
    }
  }

  disconnect() {
    this.observer.disconnect()
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    clearInterval(this.timer)
  }

  connectionChanged() {
    if (!this.source.hasAttribute("connected")) {
      this.lostConnection = true
    } else if (this.lostConnection) {
      this.lostConnection = false
      this.refresh()
    }
  }

  refresh() {
    if (document.querySelector("[data-uploading]")) {
      return
    }
    this.keepBanners()
    Turbo.visit(window.location.href, { action: "replace" })
  }

  keepBanners() {
    document.addEventListener("turbo:before-render", (event) => {
      const banners = Array.from(document.querySelectorAll("#flash > *"))
      const flash = event.detail.newBody?.querySelector("#flash")
      if (flash && banners.length > 0) {
        flash.append(...banners)
      }
    }, { once: true })
  }
}
