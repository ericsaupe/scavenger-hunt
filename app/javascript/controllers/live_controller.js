import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const CAPTURE_GRACE_MS = 3000

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
    this.onSubmitEnd = (event) => {
      if (event.detail.success && this.refreshAfterUpload) {
        this.refreshAfterUpload = false
        this.refresh()
      }
    }
    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
    if (this.intervalValue > 0) {
      this.timer = setInterval(() => this.refresh(), this.intervalValue)
    }
  }

  disconnect() {
    this.observer.disconnect()
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    clearInterval(this.timer)
    clearTimeout(this.captureTimer)
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
    if (this.waitForCapture()) {
      return
    }
    this.keepBanners()
    Turbo.visit(window.location.href, { action: "replace" })
  }

  // Opening the camera backgrounds the page, so the return fires visibilitychange
  // a moment before the input's change event; a refresh then would replace the row
  // the upload is about to submit from.
  waitForCapture() {
    const capturing = document.querySelector("[data-capturing]")
    if (!capturing) {
      return false
    }
    this.refreshAfterUpload = true
    clearTimeout(this.captureTimer)
    if (document.visibilityState === "hidden") {
      return true
    }
    this.captureTimer = setTimeout(() => {
      const field = capturing.querySelector("input[type=file]")
      if (capturing.isConnected && !capturing.hasAttribute("data-capturing")) {
        return
      }
      if (field?.files.length || document.visibilityState === "hidden") {
        this.waitForCapture()
        return
      }
      capturing.removeAttribute("data-capturing")
      this.refreshAfterUpload = false
      this.refresh()
    }, CAPTURE_GRACE_MS)
    return true
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
