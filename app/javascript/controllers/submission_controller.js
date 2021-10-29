import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "form", "icon" ]

  submitForm(event) {
    this.formTarget.requestSubmit()
    event.target.disabled = true
    this.iconTarget.innerHTML = '<ion-icon name="cloud-upload-outline" class="animate__animated animate__bounce animate__infinite"></ion-icon>'
  }
}
