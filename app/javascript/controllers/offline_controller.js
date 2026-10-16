import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "banner", "time" ]
  static values = { syncedAt: Number }

  connect() {
    this.onOnline = () => this.update(false)
    this.onOffline = () => this.update(true)
    this.onMessage = (event) => {
      if (event.data?.type === "offline-page") {
        this.update(true)
      }
    }
    window.addEventListener("online", this.onOnline)
    window.addEventListener("offline", this.onOffline)
    navigator.serviceWorker?.addEventListener("message", this.onMessage)
    this.update(!navigator.onLine)
  }

  disconnect() {
    window.removeEventListener("online", this.onOnline)
    window.removeEventListener("offline", this.onOffline)
    navigator.serviceWorker?.removeEventListener("message", this.onMessage)
  }

  update(offline) {
    this.bannerTarget.hidden = !offline
    if (offline && this.syncedAtValue) {
      this.timeTarget.textContent = new Date(this.syncedAtValue).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
    }
  }
}
