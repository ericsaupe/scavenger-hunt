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
    document.getElementById(`${this.objectValue}`).querySelector('input[type="file"]').click()
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      console.log('Escape key was pressed with out any group keys')
      this.closeModal()
    }
  }
}
