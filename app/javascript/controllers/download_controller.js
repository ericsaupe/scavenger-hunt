import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "icon" ]
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
    button.classList.remove("hover:bg-gray-200", "text-black", "focus:outline-none", "focus:ring-2", "focus:ring-white", "focus:ring-offset-2", "focus:ring-offset-gray-600")
    button.classList.add("text-gray-400", "cursor-default")
    this.iconTarget.name = "sync-outline"
    this.iconTarget.classList.add("spinning")
  }

  enableButton(button) {
    button.disabled = false
    button.classList.add("hover:bg-gray-200", "text-black", "focus:outline-none", "focus:ring-2", "focus:ring-white", "focus:ring-offset-2", "focus:ring-offset-gray-600")
    button.classList.remove("text-gray-400", "cursor-default")
    this.iconTarget.name = "cloud-download-outline"
    this.iconTarget.classList.remove("spinning")
  }

  downloadBlob(blob) {
    let file = URL.createObjectURL(blob)
    let link = document.createElement('a')
    link.href = file
    link.download = this.filenameValue
    link.click()
  }
}
