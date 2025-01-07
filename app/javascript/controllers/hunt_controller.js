import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal" ]
  static values = {
    object: String
  }

  openModal(event) {
    this.objectValue = event.target.dataset.object
    this.modalTarget.classList.add("modal-open")
    this.showContent(event)
  }

  closeModal() {
    this.modalTarget.classList.remove("modal-open")
  }

  showContent(event) {
    const title = this.modalTarget.querySelector("#title")
    title.innerHTML = event.target.dataset.title

    const content = this.modalTarget.querySelector("#content")
    if (event.target.dataset.video === 'true') {
      content.innerHTML = `<video controls src='${event.target.dataset.src}'></video>`
    } else {
      // Trying to load the image before showing it to stop the popping effect
      const img = new Image()
      img.src = event.target.dataset.src
      content.firstElementChild.remove()
      content.appendChild(img)
      this.modalTarget.focus()
    }
  }

  clickForm() {
    const fileLabel = document.querySelector(`label[for="submission_${this.objectValue}"]`)
    if (fileLabel) {
      fileLabel.click()
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.closeModal()
    }
  }
}
