import { Controller } from "@hotwired/stimulus"

const LEAVE_TIMEOUT = 800

export default class extends Controller {
  static targets = ["list"]
  static values = { mode: String, ttl: Number, limit: Number, now: String }

  initialize() {
    this.timers = new Map()
  }

  connect() {
    this.observer = new MutationObserver((mutations) => this.changed(mutations))
    this.observer.observe(this.listTarget, { childList: true })
    this.onBeforeRender = (event) => this.reconcile(event.detail.newBody)
    document.addEventListener("turbo:before-render", this.onBeforeRender)
    for (const message of this.messages) {
      this.admit(message)
    }
  }

  disconnect() {
    this.observer.disconnect()
    document.removeEventListener("turbo:before-render", this.onBeforeRender)
    for (const timer of this.timers.values()) {
      clearTimeout(timer)
    }
    this.timers.clear()
  }

  modeValueChanged() {
    if (this.hasListTarget) {
      this.prune()
    }
  }

  get messages() {
    return Array.from(this.listTarget.querySelectorAll(":scope > [data-message-id]"))
  }

  get serverNow() {
    return Date.parse(this.nowValue) || Date.now()
  }

  changed(mutations) {
    for (const mutation of mutations) {
      mutation.removedNodes.forEach((node) => this.forget(node))
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE && node.hasAttribute("data-message-id")) {
          this.admit(node)
        }
      }
    }
  }

  reconcile(newBody) {
    const fresh = newBody?.querySelector(`#${this.element.id}`)
    if (!fresh || fresh.dataset.screenChatModeValue === this.modeValue) {
      return
    }
    this.nowValue = fresh.dataset.screenChatNowValue
    this.modeValue = fresh.dataset.screenChatModeValue
    for (const row of fresh.querySelectorAll(`#${this.listTarget.id} > [data-message-id]`)) {
      if (document.getElementById(row.id)) {
        continue
      }
      const id = Number(row.dataset.messageId)
      const next = this.messages.find((message) => Number(message.dataset.messageId) > id)
      this.listTarget.insertBefore(row.cloneNode(true), next ?? null)
    }
  }

  admit(message) {
    const age = this.serverNow - Date.parse(message.querySelector("time")?.dateTime)
    const remaining = this.ttlValue - Math.max(0, Number.isFinite(age) ? age : 0)
    if (!this.welcome(message) || remaining <= 0) {
      message.remove()
      return
    }
    this.forget(message)
    this.timers.set(message, setTimeout(() => this.leave(message), remaining))
    this.trim()
  }

  welcome(message) {
    if (message.hasAttribute("data-removed")) {
      return false
    }
    return this.modeValue !== "announcements" || message.hasAttribute("data-announcement")
  }

  prune() {
    for (const message of this.messages) {
      if (!this.welcome(message)) {
        message.remove()
      }
    }
  }

  trim() {
    const messages = this.messages
    for (const message of messages.slice(0, Math.max(0, messages.length - this.limitValue))) {
      message.remove()
    }
  }

  leave(message) {
    this.forget(message)
    message.classList.add("screen-chat-leave")
    message.addEventListener("animationend", (event) => {
      if (event.target === message) {
        message.remove()
      }
    })
    setTimeout(() => message.remove(), LEAVE_TIMEOUT)
  }

  forget(node) {
    clearTimeout(this.timers.get(node))
    this.timers.delete(node)
  }
}
