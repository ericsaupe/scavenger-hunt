import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "item"]

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
