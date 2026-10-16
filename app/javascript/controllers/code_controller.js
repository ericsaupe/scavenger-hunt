import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  normalize(event) {
    const input = event.target
    const cleaned = input.value.toUpperCase().replace(/[^A-Z]/g, "").slice(0, 5)
    if (cleaned !== input.value) {
      input.value = cleaned
    }
    if (cleaned.length === 5) {
      this.element.requestSubmit()
    }
  }
}
