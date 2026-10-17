import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet", "box", "badge", "scroller", "frame", "form", "input", "counter", "nameForm", "nameInput"]
  static values = { huntId: Number, viewerId: String, url: String, max: Number }

  connect() {
    this.storageKey = `party_chat_seen_${this.huntIdValue}`
    this.lostConnection = false
    this.source = this.element.querySelector("turbo-cable-stream-source")
    this.sourceObserver = new MutationObserver(() => this.connectionChanged())
    if (this.source) {
      this.sourceObserver.observe(this.source, { attributes: true, attributeFilter: ["connected"] })
    }
    this.listObserver = new MutationObserver((mutations) => this.listChanged(mutations))
    this.listObserver.observe(this.frameTarget, { childList: true, subtree: true })
    this.onVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        this.refresh()
      }
    }
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.open) {
        this.close()
      }
    }
    document.addEventListener("keydown", this.onKeydown)

    this.decorate(this.element)
    this.updateBadge()
    this.count()
    if (this.open) {
      this.scrollToBottom()
    }
  }

  disconnect() {
    this.sourceObserver.disconnect()
    this.listObserver.disconnect()
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    document.removeEventListener("keydown", this.onKeydown)
  }

  get open() {
    return this.sheetTarget.classList.contains("modal-open")
  }

  show() {
    this.sheetTarget.classList.add("modal-open")
    this.markSeen()
    this.scrollToBottom()
    this.pendingFocus = true
    if (this.hasInputTarget && !this.inputTarget.closest("form").classList.contains("hidden")) {
      this.focus(this.inputTarget)
    } else if (this.hasNameInputTarget) {
      this.focus(this.nameInputTarget)
    }
  }

  close() {
    this.sheetTarget.classList.remove("modal-open")
    this.boxTarget.style.transform = ""
  }

  refresh() {
    const frame = this.frameTarget
    if (frame.src) {
      frame.reload()
    } else {
      frame.src = this.urlValue
    }
  }

  connectionChanged() {
    if (!this.source.hasAttribute("connected")) {
      this.lostConnection = true
    } else if (this.lostConnection) {
      this.lostConnection = false
      this.refresh()
    }
  }

  listChanged(mutations) {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          this.decorate(node)
        }
      }
    }
    if (this.open) {
      this.markSeen()
      if (this.nearBottom) {
        this.scrollToBottom()
      }
    } else {
      this.updateBadge()
    }
  }

  decorate(root) {
    const messages = root.matches?.("[data-message-id]") ? [root] : root.querySelectorAll("[data-message-id]")
    for (const message of messages) {
      if (message.dataset.senderId === this.viewerIdValue) {
        message.setAttribute("data-own", "")
      }
    }
    for (const time of root.querySelectorAll("time[data-chat-time]")) {
      const at = new Date(time.dateTime)
      const hours = at.getHours() % 12 || 12
      time.textContent = `${hours}:${String(at.getMinutes()).padStart(2, "0")}`
    }
  }

  get messageElements() {
    return Array.from(this.frameTarget.querySelectorAll("[data-message-id]"))
  }

  get seenId() {
    try {
      return Number(localStorage.getItem(this.storageKey)) || 0
    } catch {
      return 0
    }
  }

  markSeen() {
    const latest = Math.max(0, ...this.messageElements.map((element) => Number(element.dataset.messageId)))
    if (latest > this.seenId) {
      try {
        localStorage.setItem(this.storageKey, latest)
      } catch {}
    }
    this.updateBadge()
  }

  updateBadge() {
    const seen = this.seenId
    const unread = this.open ? 0 : this.messageElements.filter((element) =>
      Number(element.dataset.messageId) > seen && element.dataset.senderId !== this.viewerIdValue
    ).length
    this.badgeTarget.hidden = unread === 0
    this.badgeTarget.textContent = unread > 99 ? "99+" : unread
  }

  get nearBottom() {
    const scroller = this.scrollerTarget
    return scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight < 120
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.scrollerTarget.scrollTop = this.scrollerTarget.scrollHeight
    })
  }

  focus(field) {
    requestAnimationFrame(() => field.focus({ preventScroll: true }))
  }

  count() {
    if (!this.hasCounterTarget || !this.hasInputTarget) return
    const length = this.inputTarget.value.length
    this.counterTarget.textContent = `${length}/${this.maxValue}`
    this.counterTarget.classList.toggle("text-error", length > this.maxValue - 20)
  }

  sent(event) {
    if (!event.detail.success) return
    this.formTarget.reset()
    this.count()
    this.scrollToBottom()
    this.focus(this.inputTarget)
  }

  editName() {
    this.nameFormTarget.classList.remove("hidden")
    this.formTarget.classList.add("hidden")
    this.nameInputTarget.select()
    this.focus(this.nameInputTarget)
  }

  nameSubmitted() {
    this.pendingFocus = true
  }

  inputTargetConnected(input) {
    if (this.pendingFocus && this.open) {
      this.pendingFocus = false
      this.focus(input)
    }
  }

  dragStart(event) {
    this.dragFrom = event.clientY
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  dragMove(event) {
    if (this.dragFrom === undefined) return
    const distance = Math.max(0, event.clientY - this.dragFrom)
    this.boxTarget.style.transform = `translateY(${distance}px)`
  }

  dragEnd(event) {
    if (this.dragFrom === undefined) return
    const distance = event.clientY - this.dragFrom
    this.dragFrom = undefined
    if (distance > 80) {
      this.close()
    } else {
      this.boxTarget.style.transform = ""
    }
  }
}
