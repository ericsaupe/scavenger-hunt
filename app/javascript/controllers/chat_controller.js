import { Controller } from "@hotwired/stimulus"

const VISIT_GRACE_MS = 10000
const FOCUSABLE = "a[href], button:not([disabled]), input:not([disabled]):not([type=hidden]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"

export default class extends Controller {
  static targets = ["pill", "sheet", "box", "badge", "scroller", "frame", "form", "input", "counter", "nameForm", "nameInput", "announcement", "announcementToggle"]
  static values = { huntId: Number, viewer: String, url: String, max: Number }

  connect() {
    this.storageKey = `party_chat_seen_${this.huntIdValue}`
    this.lostConnection = false
    this.atBottom = true
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
    this.onKeydown = (event) => this.keydown(event)
    document.addEventListener("keydown", this.onKeydown)
    this.onBeforeRender = (event) => this.syncWithRender(event)
    document.addEventListener("turbo:before-render", this.onBeforeRender)
    this.onBeforeFrameRender = (event) => {
      if (event.target === this.frameTarget) {
        this.snapshotComposer()
      }
    }
    this.frameTarget.addEventListener("turbo:before-frame-render", this.onBeforeFrameRender)
    this.onVisit = () => {
      this.visitStartedAt = Date.now()
    }
    document.addEventListener("turbo:visit", this.onVisit)
    this.onLoad = () => {
      this.visitStartedAt = null
      if (this.reloadAfterVisit) {
        this.reloadAfterVisit = false
        this.reload()
      }
    }
    document.addEventListener("turbo:load", this.onLoad)

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
    document.removeEventListener("turbo:before-render", this.onBeforeRender)
    this.frameTarget.removeEventListener("turbo:before-frame-render", this.onBeforeFrameRender)
    document.removeEventListener("turbo:visit", this.onVisit)
    document.removeEventListener("turbo:load", this.onLoad)
  }

  get open() {
    return this.sheetTarget.classList.contains("modal-open")
  }

  show() {
    this.opener = document.activeElement
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
    if (!this.open) return
    this.sheetTarget.classList.remove("modal-open")
    this.boxTarget.style.transform = ""
    const opener = this.opener?.isConnected ? this.opener : this.pillTarget
    this.opener = null
    opener.focus({ preventScroll: true })
  }

  keydown(event) {
    if (!this.open) return
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    } else if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  trapFocus(event) {
    const focusable = Array.from(this.boxTarget.querySelectorAll(FOCUSABLE)).filter((element) => element.offsetParent !== null)
    if (focusable.length === 0) return
    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    const inside = this.boxTarget.contains(document.activeElement)
    if (event.shiftKey && (document.activeElement === first || !inside)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && (document.activeElement === last || !inside)) {
      event.preventDefault()
      first.focus()
    }
  }

  // A page visit moves this permanent element into the new body, and Turbo
  // restarts a frame load that was still in flight when it moved, so the
  // sheet would render twice. Reload once after the visit lands instead.
  refresh() {
    setTimeout(() => {
      if (this.visitStartedAt > Date.now() - VISIT_GRACE_MS) {
        this.reloadAfterVisit = true
      } else {
        this.reload()
      }
    })
  }

  reload() {
    const frame = this.frameTarget
    if (frame.src) {
      frame.reload()
    } else {
      frame.src = this.urlValue
    }
  }

  syncWithRender(event) {
    const fresh = event.detail.newBody?.querySelector(`#${this.frameTarget.id}`)
    if (!fresh || fresh.dataset.chatRole === this.shownRole) return
    this.frameTarget.dataset.chatRole = fresh.dataset.chatRole
    this.refresh()
  }

  get shownRole() {
    const box = this.frameTarget.querySelector("[data-chat-box]")
    if (!box) return this.frameTarget.dataset.chatRole
    return box.hasAttribute("data-chat-organizer") ? "organizer" : "guest"
  }

  snapshotComposer() {
    this.draftInput = this.hasInputTarget ? this.inputTarget : null
    this.draft = this.draftInput?.value ?? null
    this.draftAnnouncement = this.hasAnnouncementToggleTarget && this.announcementToggleTarget.getAttribute("aria-pressed") === "true"
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
    let messagesAdded = false
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) continue
        this.decorate(node)
        if (node.matches("[data-message-id]") || node.querySelector("[data-message-id]")) {
          messagesAdded = true
        }
      }
    }
    if (!messagesAdded) return
    if (this.open) {
      this.markSeen()
      if (this.atBottom) {
        this.scrollToBottom()
      }
    } else {
      this.updateBadge()
    }
  }

  decorate(root) {
    const messages = root.matches?.("[data-message-id]") ? [root] : root.querySelectorAll("[data-message-id]")
    for (const message of messages) {
      if (message.dataset.sender === this.viewerValue) {
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
      Number(element.dataset.messageId) > seen && element.dataset.sender !== this.viewerValue
    ).length
    this.badgeTarget.hidden = unread === 0
    this.badgeTarget.textContent = unread > 99 ? "99+" : unread
  }

  scrolled() {
    const scroller = this.scrollerTarget
    this.atBottom = scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight < 120
  }

  scrollToBottom() {
    this.atBottom = true
    requestAnimationFrame(() => {
      if (!this.hasScrollerTarget) return
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
    this.setAnnouncement(false)
    this.count()
    this.scrollToBottom()
    this.focus(this.inputTarget)
  }

  toggleAnnouncement() {
    this.setAnnouncement(this.announcementToggleTarget.getAttribute("aria-pressed") !== "true")
    this.focus(this.inputTarget)
  }

  setAnnouncement(on) {
    if (!this.hasAnnouncementToggleTarget) return
    this.announcementToggleTarget.setAttribute("aria-pressed", String(on))
    this.announcementTarget.value = on ? "1" : "0"
    this.inputTarget.placeholder = on ? "Announce something to everyone" : "Say something to everyone"
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
    if (input !== this.draftInput) {
      if (this.draft != null) {
        input.value = this.draft
        this.count()
      }
      if (this.draftAnnouncement) {
        this.setAnnouncement(true)
      }
      this.draft = null
      this.draftAnnouncement = false
      this.draftInput = null
    }
    if (this.pendingFocus && this.open) {
      this.pendingFocus = false
      this.focus(input)
    }
  }

  scrollerTargetConnected() {
    if (this.open) {
      this.scrollToBottom()
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
