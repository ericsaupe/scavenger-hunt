import { Controller } from "@hotwired/stimulus"

const DISMISSED_KEY = "installPromptDismissed"

export default class extends Controller {
  static targets = [ "android", "ios" ]

  connect() {
    if (this.dismissed || this.installed) {
      return
    }

    this.onReady = () => this.show(this.androidTarget)
    window.addEventListener("install-prompt:ready", this.onReady)

    if (window.deferredInstallPrompt) {
      this.show(this.androidTarget)
    } else if (this.ios) {
      this.show(this.iosTarget)
    }
  }

  disconnect() {
    window.removeEventListener("install-prompt:ready", this.onReady)
  }

  async install() {
    const prompt = window.deferredInstallPrompt
    if (!prompt) {
      return
    }
    window.deferredInstallPrompt = null
    prompt.prompt()
    await prompt.userChoice.catch(() => {})
    this.dismiss()
  }

  dismiss() {
    try {
      localStorage.setItem(DISMISSED_KEY, "true")
    } catch (e) {
    }
    this.element.hidden = true
  }

  show(sheet) {
    this.androidTarget.hidden = sheet !== this.androidTarget
    this.iosTarget.hidden = sheet !== this.iosTarget
    this.element.hidden = false
  }

  get dismissed() {
    try {
      return localStorage.getItem(DISMISSED_KEY) === "true"
    } catch (e) {
      return false
    }
  }

  get installed() {
    return window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true
  }

  get ios() {
    const ua = navigator.userAgent
    const iPadOS = navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1
    return (/iPhone|iPad|iPod/.test(ua) || iPadOS) && /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS/.test(ua)
  }
}
