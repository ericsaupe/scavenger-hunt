import { Controller } from "@hotwired/stimulus"
import Compress from "compress.js"

export default class extends Controller {
  static targets = [ "field", "form", "slot" ]
  static values = {
    submitting: { type: Boolean, default: false }
  }

  submitForm(event) {
    if (this.submittingValue) {
      return
    }

    const file = this.fieldTarget.files[0]
    if (!file) {
      return
    }

    this.submittingValue = true
    this.showUploading(file)

    this.compressImage(file).then(() => {
      if (this.formTarget.requestSubmit) {
        this.formTarget.requestSubmit()
      } else {
        fetch(this.formTarget.action, {
          method: this.formTarget.method,
          body: new FormData(this.formTarget),
        })
      }
      event.target.disabled = true
    }).catch((e) => {
      this.submittingValue = false
      this.showIdle()
      this.addBanner(e.message)
    })
  }

  showUploading(file) {
    this.element.dataset.uploading = "true"
    if (!this.hasSlotTarget) {
      return
    }

    this.slotTarget.replaceChildren()
    this.slotTarget.classList.remove("border-dashed")
    this.slotTarget.classList.add("overflow-hidden", "border-marigold", "relative")

    if (file.type.startsWith("image/")) {
      const img = document.createElement("img")
      img.src = URL.createObjectURL(file)
      img.alt = ""
      img.className = "size-full object-cover animate-breathe"
      img.onload = () => URL.revokeObjectURL(img.src)
      this.slotTarget.appendChild(img)
    } else {
      const spinner = document.createElement("span")
      spinner.className = "loading loading-spinner loading-sm text-marigold"
      this.slotTarget.appendChild(spinner)
    }
  }

  showIdle() {
    delete this.element.dataset.uploading
  }

  addBanner(message) {
    fetch(`/banner?message=${encodeURIComponent(message)}`)
      .then((response) => response.text())
      .then((html) => {
        const flash = document.getElementById("flash")
        if (flash) {
          flash.insertAdjacentHTML("beforeend", html)
        }
      })
  }

  compressImage(file) {
    return new Promise((resolve, reject) => {
      if (!file.type.startsWith("image/")) {
        return resolve()
      }
      try {
        const compress = new Compress({ maxWidth: 1920, maxHeight: 1920, quality: 0.75 })
        // compress.js re-encodes to the input's type, so label the input as JPEG to always upload JPEG
        const jpeg = new File([file], file.name.replace(/\.[^.]+$/, "") + ".jpg", { type: "image/jpeg" })
        compress.compress(jpeg).then((compressed) => {
          const transfer = new DataTransfer()
          transfer.items.add(compressed)
          this.fieldTarget.files = transfer.files
          resolve()
        }).catch(reject)
      } catch (e) {
        reject(e)
      }
    })
  }

  openFileField() {
    this.fieldTarget.click()
  }
}
