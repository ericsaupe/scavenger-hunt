import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "field", "form", "icon" ]

  initialize() {
    this.boundSubmitForm = this.submitForm.bind(this);
  }

  connect() {
    this.fieldTarget.addEventListener("change", this.boundSubmitForm);
  }

  disconnect() {
    this.fieldTarget.removeEventListener("change", this.boundSubmitForm);
  }

  submitForm(event) {
    this.formTarget.requestSubmit()
    event.target.disabled = true
    this.iconTarget.innerHTML = '<ion-icon name="cloud-upload-outline" class="animate__animated animate__bounce animate__infinite"></ion-icon>'
  }
}
