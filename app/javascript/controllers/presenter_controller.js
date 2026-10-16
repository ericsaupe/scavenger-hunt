import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "previous", "next" ]

  connect() {
    this.onKeydown = (event) => {
      if (event.target.closest("input, textarea")) {
        return
      }
      if (event.key === "ArrowRight" && this.hasNextTarget) {
        this.nextTarget.click()
      } else if (event.key === "ArrowLeft" && this.hasPreviousTarget) {
        this.previousTarget.click()
      }
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }
}
