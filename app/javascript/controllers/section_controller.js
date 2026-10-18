import { Controller } from "@hotwired/stimulus"

const FOLD_DELAY_MS = 600
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30

export default class extends Controller {
  static targets = [ "toggle", "body", "list", "count", "bar" ]
  static values = { key: String, cookie: String }

  connect() {
    this.complete = this.element.hasAttribute("data-complete")
    this.fold(this.wantsFolded, { animate: false })
    this.observer = new MutationObserver(() => this.update())
    this.observer.observe(this.listTarget, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-found"] })
  }

  disconnect() {
    this.observer.disconnect()
    clearTimeout(this.foldTimer)
  }

  toggle() {
    const folded = !this.folded
    const folds = this.folds
    if (folded === this.complete) {
      delete folds[this.keyValue]
    } else {
      folds[this.keyValue] = folded ? "closed" : "open"
    }
    this.folds = folds
    clearTimeout(this.foldTimer)
    this.fold(folded)
  }

  update() {
    const total = this.listTarget.querySelectorAll("li[data-item]").length
    const found = this.listTarget.querySelectorAll("li[data-found]").length
    const complete = total > 0 && found === total
    this.countTarget.textContent = complete ? `All ${total} found` : `${found} of ${total} found`
    this.barTarget.style.width = total > 0 ? `${Math.round((found / total) * 100)}%` : "0%"
    if (complete === this.complete) {
      return
    }
    this.complete = complete
    this.element.toggleAttribute("data-complete", complete)
    clearTimeout(this.foldTimer)
    this.foldTimer = setTimeout(() => this.fold(this.wantsFolded), FOLD_DELAY_MS)
  }

  // A section folding while its header is out of sight, above the screen or under
  // the sticky header, would drag everything below it upwards, so it folds at once
  // and the scroll position takes up the difference. The correction stops once the
  // card sits just under the sticky header, so folding a long section the team is
  // partway down shows its card rather than the sections before it.
  fold(folded, { animate = true } = {}) {
    if (folded === this.folded) {
      return
    }
    const covered = document.querySelector("[data-sticky-header]")?.getBoundingClientRect().bottom ?? 0
    const { top, bottom } = this.element.getBoundingClientRect()
    const offscreen = top < covered
    const animated = [this.toggleTarget, this.bodyTarget]
    if (offscreen || !animate) {
      animated.forEach((element) => { element.style.transition = "none" })
    }
    this.element.toggleAttribute("data-folded", folded)
    this.toggleTarget.setAttribute("aria-expanded", !folded)
    this.bodyTarget.inert = folded
    const after = this.element.getBoundingClientRect()
    if (offscreen) {
      window.scrollBy(0, Math.max(after.bottom - bottom, after.top - covered))
    }
    requestAnimationFrame(() => animated.forEach((element) => { element.style.transition = "" }))
  }

  get folded() {
    return this.element.hasAttribute("data-folded")
  }

  get wantsFolded() {
    const fold = this.folds[this.keyValue]
    return fold ? fold === "closed" : this.complete
  }

  get folds() {
    const cookie = document.cookie.split("; ").find((pair) => pair.startsWith(`${this.cookieValue}=`))
    if (!cookie) {
      return {}
    }
    try {
      const folds = JSON.parse(decodeURIComponent(cookie.slice(this.cookieValue.length + 1)))
      return folds?.constructor === Object ? folds : {}
    } catch {
      return {}
    }
  }

  set folds(folds) {
    const maxAge = Object.keys(folds).length > 0 ? COOKIE_MAX_AGE : 0
    document.cookie = `${this.cookieValue}=${encodeURIComponent(JSON.stringify(folds))}; path=/; max-age=${maxAge}; samesite=lax`
  }
}
