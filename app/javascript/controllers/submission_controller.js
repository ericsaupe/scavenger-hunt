import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import Compress from "compress.js"

const UPLOAD_FAILED = "Your photo couldn't be uploaded. Check your connection and try again."

export default class extends Controller {
  static targets = [ "field", "form", "slot", "capturedAt" ]
  static values = {
    submitting: { type: Boolean, default: false },
    maxVideoBytes: Number,
    maxVideoSeconds: Number,
    attempts: { type: Number, default: 3 },
    retryDelay: { type: Number, default: 1000 }
  }

  async submitForm() {
    if (this.submittingValue) {
      return
    }

    const file = this.fieldTarget.files[0]
    if (!file) {
      return
    }

    this.submittingValue = true
    this.capturedAtTarget.value = new Date().toISOString()

    const problem = await this.mediaProblem(file)
    if (problem) {
      this.submittingValue = false
      this.fieldTarget.value = ""
      this.addBanner(problem)
      return
    }

    this.showUploading(file)
    this.pendingFile = await this.compressImage(file)
    this.retryUpload()
  }

  async upload() {
    const blob = await this.uploadWithRetries(this.pendingFile)
    this.setSignedId(blob.signed_id)
    this.fieldTarget.disabled = true
    this.formTarget.requestSubmit()
  }

  retryUpload() {
    this.submittingValue = true
    this.element.dataset.uploading = "true"
    this.upload().catch(() => this.uploadFailed(() => this.retryUpload()))
  }

  submitEnd(event) {
    if (event.detail.success || event.detail.fetchResponse?.statusCode === 422 || !this.element.isConnected) {
      return
    }

    this.uploadFailed(() => {
      this.submittingValue = true
      this.element.dataset.uploading = "true"
      this.formTarget.requestSubmit()
    })
  }

  uploadFailed(retry) {
    this.submittingValue = false
    this.showIdle()
    this.addBanner(UPLOAD_FAILED, { actionLabel: "Try again", onAction: retry })
  }

  async uploadWithRetries(file) {
    const url = this.fieldTarget.dataset.directUploadUrl

    for (let attempt = 1; ; attempt++) {
      try {
        return await this.directUpload(file, url)
      } catch (e) {
        if (attempt >= this.attemptsValue) {
          throw e
        }
        await new Promise((resolve) => setTimeout(resolve, this.retryDelayValue * 2 ** (attempt - 1)))
      }
    }
  }

  directUpload(file, url) {
    return new Promise((resolve, reject) => {
      new DirectUpload(file, url).create((error, blob) => {
        if (error) {
          reject(new Error(error))
        } else {
          resolve(blob)
        }
      })
    })
  }

  setSignedId(signedId) {
    let input = this.formTarget.querySelector("input[type=hidden][name='submission[photo]']")
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = "submission[photo]"
      this.formTarget.appendChild(input)
    }
    input.value = signedId
  }

  async mediaProblem(file) {
    if (file.type.startsWith("image/")) {
      return null
    }
    if (!file.type.startsWith("video/")) {
      return "Only photos and videos can be uploaded."
    }
    if (file.size > this.maxVideoBytesValue) {
      return `Videos must be ${Math.round(this.maxVideoBytesValue / 1048576)} MB or smaller. Try a shorter clip.`
    }
    const duration = await this.videoDuration(file)
    if (duration > this.maxVideoSecondsValue) {
      return `Videos must be ${this.maxVideoSecondsValue} seconds or shorter. Try a shorter clip.`
    }
    return null
  }

  videoDuration(file) {
    return new Promise((resolve) => {
      const video = document.createElement("video")
      video.preload = "metadata"
      const finish = (duration) => {
        clearTimeout(timeout)
        URL.revokeObjectURL(video.src)
        resolve(Number.isFinite(duration) ? duration : 0)
      }
      const timeout = setTimeout(() => finish(0), 10000)
      video.onloadedmetadata = () => finish(video.duration)
      video.onerror = () => finish(0)
      video.src = URL.createObjectURL(file)
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

  addBanner(message, { actionLabel, onAction } = {}) {
    const template = document.getElementById("banner_template")
    const flash = document.getElementById("flash")
    if (!template || !flash) {
      return
    }

    const banner = template.content.firstElementChild.cloneNode(true)
    banner.querySelector("[data-banner-message]").textContent = message
    const action = banner.querySelector("[data-banner-action]")
    if (actionLabel) {
      action.textContent = actionLabel
      action.addEventListener("click", onAction)
      banner.dataset.flashStickyValue = "true"
    } else {
      action.remove()
      banner.dataset.flashStickyValue = "false"
    }
    flash.appendChild(banner)
  }

  async compressImage(file) {
    if (!file.type.startsWith("image/")) {
      return file
    }
    try {
      // compress.js never settles for an image the browser cannot decode, so decode it first and
      // fall back to uploading the original when that fails
      await createImageBitmap(file)
      const compress = new Compress({ maxWidth: 1920, maxHeight: 1920, quality: 0.75 })
      // compress.js re-encodes to the input's type, so label the input as JPEG to always upload JPEG
      const jpeg = new File([file], file.name.replace(/\.[^.]+$/, "") + ".jpg", { type: "image/jpeg" })
      return await compress.compress(jpeg)
    } catch (e) {
      return file
    }
  }

  openFileField() {
    this.fieldTarget.click()
  }
}
