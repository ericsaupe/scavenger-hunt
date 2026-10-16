import { Controller } from "@hotwired/stimulus"
import { supported, installed, permission, optOut, currentSubscription, subscribe, unsubscribe, send } from "../push/client"

export default class extends Controller {
  static targets = [ "toggles", "enable", "preference" ]
  static values = { url: String, publicKey: String, code: String, subscribed: Boolean }

  connect() {
    if (!supported() || !this.publicKeyValue) {
      return
    }

    this.onSubscribed = () => {
      this.subscribedValue = true
      this.render(true)
    }
    window.addEventListener("push:subscribed", this.onSubscribed)
    this.reveal()
  }

  disconnect() {
    window.removeEventListener("push:subscribed", this.onSubscribed)
  }

  async reveal() {
    let subscription = null
    if (permission() === "granted") {
      subscription = await currentSubscription().catch(() => null)
    }
    if (installed() || subscription) {
      this.render(Boolean(subscription) && this.subscribedValue)
    }
  }

  async update(event) {
    const field = event.target
    field.disabled = true
    try {
      await send(this.urlValue, "PATCH", { push_subscription: { [field.name]: field.checked } })
    } catch (error) {
      field.checked = !field.checked
      console.error(error)
    } finally {
      field.disabled = false
    }
  }

  async enable() {
    try {
      if (await Notification.requestPermission() !== "granted") {
        return
      }
      optOut.clear(this.codeValue)
      const subscription = await subscribe(this.publicKeyValue)
      await send(this.urlValue, "POST", { subscription: subscription.toJSON() })
      this.preferenceTargets.forEach((field) => field.checked = true)
      this.subscribedValue = true
      this.render(true)
    } catch (error) {
      console.error(error)
    }
  }

  async disable() {
    optOut.set(this.codeValue)
    try {
      await send(this.urlValue, "DELETE")
      await unsubscribe()
    } catch (error) {
      console.error(error)
    }
    this.subscribedValue = false
    this.render(false)
  }

  render(subscribed) {
    this.togglesTarget.hidden = !subscribed
    this.enableTarget.hidden = subscribed
    this.element.hidden = false
  }
}
