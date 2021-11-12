import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "form", "icon" ]

  submitForm(event) {
    if (this.formTarget.requestSubmit){
      this.formTarget.requestSubmit()
    } else {
      this.formTarget.submit()
    }
    event.target.disabled = true
    this.iconTarget.innerHTML = '<ion-icon name="cloud-upload-outline" class="animate__animated animate__bounce animate__infinite"></ion-icon>'
  }
}
