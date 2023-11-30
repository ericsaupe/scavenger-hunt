import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.parentElement.scrollTo({ behavior: 'smooth', top: this.element.offsetTop })
  }
}
