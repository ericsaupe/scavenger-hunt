import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "icon", "loadingIcon" ]
  static values = {
    filename: String
  }

  toggleDownload(event) {
    event.preventDefault()
    let button = event.target

    this.disableButton(button)

    fetch(event.target.href)
      .then(res => res.blob())
      .then(blob => this.downloadBlob(blob))
      .catch((e) => console.log(e))
      .finally(() => this.enableButton(button))
  }

  disableButton(button) {
    button.disabled = true
    button.classList.add('btn-disabled')
    this.iconTarget.classList.add('hidden')
    this.loadingIconTarget.classList.remove('hidden')
  }

  enableButton(button) {
    button.disabled = false
    button.classList.remove('btn-disabled')
    this.iconTarget.classList.remove('hidden')
    this.loadingIconTarget.classList.add('hidden')
  }

  downloadBlob(blob) {
    let file = URL.createObjectURL(blob)
    let link = document.createElement('a')
    link.href = file
    link.download = this.filenameValue
    link.click()
  }
}
