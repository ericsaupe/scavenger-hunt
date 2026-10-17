import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "title", "content", "capture", "captureTitle" ]

  openModal(event) {
    const data = event.currentTarget.dataset
    this.fieldId = data.field
    this.titleTarget.textContent = data.title

    this.contentTarget.replaceChildren()
    if (data.video === "true") {
      const video = document.createElement("video")
      video.controls = true
      video.playsInline = true
      video.src = data.src
      if (data.poster) {
        video.poster = data.poster
      }
      video.className = "max-h-[65dvh] w-full"
      this.contentTarget.appendChild(video)
    } else {
      const img = new Image()
      img.src = data.src
      img.alt = data.title
      img.className = "max-h-[65dvh] w-full object-contain"
      this.contentTarget.appendChild(img)
    }

    if (!this.modalTarget.open) {
      this.modalTarget.showModal()
    }
  }

  closeModal() {
    if (this.modalTarget.open) {
      this.modalTarget.close()
    }
  }

  openCapture(event) {
    const data = event.currentTarget.dataset
    this.fieldId = data.field
    this.captureTitleTarget.textContent = data.title
    this.showCapture()
  }

  retake() {
    this.captureTitleTarget.textContent = this.titleTarget.textContent
    this.closeModal()
    this.showCapture()
  }

  capture(event) {
    const field = document.getElementById(this.fieldId)
    this.closeCapture()
    if (!field || field.disabled) {
      return
    }
    const { accept, capture } = event.currentTarget.dataset
    field.accept = accept
    if (capture) {
      field.setAttribute("capture", capture)
    } else {
      field.removeAttribute("capture")
    }
    field.click()
  }

  showCapture() {
    const field = document.getElementById(this.fieldId)
    if (!field || field.disabled) {
      return
    }
    if (!this.captureTarget.open) {
      this.captureTarget.showModal()
    }
  }

  closeCapture() {
    if (this.captureTarget.open) {
      this.captureTarget.close()
    }
  }
}
