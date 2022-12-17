import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal" ]
  static values = {
    object: String
  }

  connect() {
    setTimeout(() => {
      this.modalTarget.classList.remove("hidden")
    }, 500)
  }

  openModal(event) {
    this.modalTarget.classList.remove('pointer-events-none')
    this.objectValue = event.target.dataset.object

    const overlay = this.modalTarget.querySelector("#overlay")
    const panel = this.modalTarget.querySelector("#panel")
    this.showContent(event)

    overlay.classList.remove("opacity-0")
    overlay.classList.add("opacity-100")
    panel.classList.remove("opacity-0", "translate-y-4", "sm:translate-y-0", "sm:scale-95")
    panel.classList.add("opacity-100", "translate-y-0", "sm:scale-100")
  }

  closeModal() {
    this.modalTarget.classList.add('pointer-events-none')
    this.objectValue = null

    const overlay = this.modalTarget.querySelector("#overlay")
    const panel = this.modalTarget.querySelector("#panel")

    overlay.classList.add("opacity-0")
    overlay.classList.remove("opacity-100")
    panel.classList.add("opacity-0", "translate-y-4", "sm:translate-y-0", "sm:scale-95")
    panel.classList.remove("opacity-100", "translate-y-0", "sm:scale-100")
  }

  showContent(event) {
    const title = this.modalTarget.querySelector("#title")
    title.innerHTML = event.target.dataset.title

    const content = this.modalTarget.querySelector("#content")
    if (event.target.dataset.video === 'true') {
      content.innerHTML = `<video class="m-auto sm:flex-grow h-fit max-h-[85vh]" controls loop src='${event.target.dataset.src}'></video>`
    } else {
      // Trying to load the image before showing it to stop the popping effect
      const img = new Image()
      img.src = event.target.dataset.src
      img.classList.add("m-auto", "h-fit", "max-h-[85vh]", "object-contain")
      content.appendChild(img)
      content.firstElementChild.remove()
    }
  }

  clickForm() {
    document.getElementById(`${this.objectValue}`).querySelector('input[type="file"]').click()
  }
}
