import { Controller } from "@hotwired/stimulus"

const FIT = "(min-width: 640px) and (min-height: 640px)"

export default class extends Controller {
  static targets = ["track", "item", "card", "media"]

  connect() {
    this.observer = new ResizeObserver(() => this.fit())
    this.observer.observe(this.trackTarget)
    this.mediaTargets.forEach(media => this.observer.observe(media))
    this.fit()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  fit() {
    const wide = window.matchMedia(FIT).matches
    this.cardTargets.forEach(card => { card.style.width = "" })
    if (!wide) {
      return
    }
    const widths = this.cardTargets.map((card, index) => {
      const media = this.mediaTargets[index]
      if (!media) {
        return null
      }
      const style = getComputedStyle(card)
      const padding = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight)
      return Math.ceil(Math.max(media.getBoundingClientRect().width + padding, parseFloat(style.minWidth) || 0))
    })
    this.cardTargets.forEach((card, index) => {
      if (widths[index]) {
        card.style.width = `${widths[index]}px`
      }
    })
  }

  show({ params: { index } }) {
    const item = this.itemTargets[index]
    if (!item) {
      return
    }
    const offset = item.getBoundingClientRect().left - this.trackTarget.getBoundingClientRect().left
    const centering = (this.trackTarget.clientWidth - item.offsetWidth) / 2
    this.trackTarget.scrollTo({ left: this.trackTarget.scrollLeft + offset - centering })
  }
}
