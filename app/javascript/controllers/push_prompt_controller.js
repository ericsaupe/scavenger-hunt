import { Controller } from "@hotwired/stimulus"
import { supported, installed, permission, prompt, optOut, currentSubscription, subscribe, send } from "../push/client"

export default class extends Controller {
  static values = { url: String, publicKey: String, code: String, subscribed: Boolean }

  connect() {
    if (!supported() || !this.publicKeyValue) {
      return
    }

    this.onInstalled = () => {
      if (permission() === "default" && !prompt.dismissed()) {
        this.show()
      }
    }
    window.addEventListener("install:accepted", this.onInstalled)

    if (permission() === "granted") {
      this.register()
    } else if (permission() === "default" && (installed() || prompt.pending()) && !prompt.dismissed()) {
      this.show()
    }
  }

  disconnect() {
    window.removeEventListener("install:accepted", this.onInstalled)
  }

  async allow() {
    this.hide()
    prompt.clearPending()
    try {
      if (await Notification.requestPermission() !== "granted") {
        prompt.dismiss()
        return
      }
      optOut.clear(this.codeValue)
      await this.save(await subscribe(this.publicKeyValue))
    } catch (error) {
      console.error(error)
    }
  }

  dismiss() {
    prompt.dismiss()
    prompt.clearPending()
    this.hide()
  }

  async register() {
    if (this.subscribedValue || optOut.active(this.codeValue)) {
      return
    }
    try {
      const subscription = await currentSubscription()
      if (subscription) {
        await this.save(subscription)
      }
    } catch (error) {
      console.error(error)
    }
  }

  async save(subscription) {
    await send(this.urlValue, "POST", { subscription: subscription.toJSON() })
    this.subscribedValue = true
    window.dispatchEvent(new CustomEvent("push:subscribed"))
  }

  show() {
    this.element.hidden = false
  }

  hide() {
    this.element.hidden = true
  }
}
