import { Controller } from "@hotwired/stimulus"
import Compress from "compress.js"
import { addBanner } from "../banners"
import { uploadWithRetries } from "../uploads/direct_upload"
import { enqueue } from "../uploads/queue"
import { registerSync } from "../uploads/drain"
import { showIdle, showPending, showQueued } from "../uploads/pending"

const TYPES_BY_EXTENSION = {
  jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", gif: "image/gif", webp: "image/webp", heic: "image/heic", heif: "image/heif", avif: "image/avif",
  mp4: "video/mp4", mov: "video/quicktime", webm: "video/webm", "3gp": "video/3gpp"
}
const UPLOAD_FAILED = "Your photo couldn't be uploaded. Check your connection and try again."

export default class extends Controller {
  static targets = [ "field", "form", "slot", "hint", "capturedAt" ]
  static values = {
    submitting: { type: Boolean, default: false },
    maxVideoBytes: Number,
    maxVideoSeconds: Number,
    acceptedTypes: String,
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
      delete this.element.dataset.capturing
      addBanner(problem)
      return
    }

    delete this.element.dataset.capturing
    const uploading = !!this.element.dataset.uploading
    this.retake = !!this.element.dataset.found || uploading
    showPending(this.element, file)
    this.pendingFile = await this.compressImage(file)

    if (navigator.onLine && !uploading) {
      this.retryUpload()
    } else {
      this.queue()
    }
  }

  async upload() {
    const blob = await uploadWithRetries(this.pendingFile, this.fieldTarget.dataset.directUploadUrl, {
      attempts: this.attemptsValue,
      retryDelay: this.retryDelayValue
    })
    this.setSignedId(blob.signed_id)
    this.fieldTarget.disabled = true
    this.formTarget.requestSubmit()
  }

  retryUpload() {
    this.submittingValue = true
    this.element.dataset.uploading = "true"
    this.upload().catch(() => this.queue())
  }

  submitEnd(event) {
    if (event.detail.success || event.detail.fetchResponse?.statusCode === 422 || !this.element.isConnected) {
      return
    }

    if (!event.detail.fetchResponse) {
      this.queue()
      return
    }

    this.submittingValue = false
    showIdle(this.element)
    addBanner(UPLOAD_FAILED, {
      actionLabel: "Try again",
      onAction: () => {
        this.submittingValue = true
        this.element.dataset.uploading = "true"
        this.formTarget.requestSubmit()
      }
    })
  }

  async queue() {
    const file = this.pendingFile
    await enqueue({
      submissionId: Number(this.element.dataset.submissionId),
      itemId: Number(this.element.dataset.item),
      teamId: Number(this.element.dataset.team),
      capturedAt: this.capturedAtTarget.value,
      file,
      retake: this.retake,
      directUploadUrl: this.fieldTarget.dataset.directUploadUrl,
      updateUrl: this.formTarget.action
    })
    this.submittingValue = false
    this.fieldTarget.disabled = false
    this.fieldTarget.value = ""
    showQueued(this.element, file)
    registerSync()
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
    const type = this.mediaType(file)
    if (type.startsWith("image/") && type !== "image/unknown" && !this.accepted(type)) {
      return "That image type can't be used. Take a photo instead."
    }
    if (type.startsWith("image/")) {
      return null
    }
    if (!type.startsWith("video/")) {
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

  accepted(type) {
    const types = this.acceptedTypesValue.split(",").filter(Boolean)
    return types.length === 0 || types.includes(type)
  }

  // Android's camera sometimes hands back a file with no type at all, so fall back
  // to the extension and otherwise let the server identify the bytes.
  mediaType(file) {
    if (file.type) {
      return file.type
    }
    const extension = file.name.split(".").pop().toLowerCase()
    if (TYPES_BY_EXTENSION[extension]) {
      return TYPES_BY_EXTENSION[extension]
    }
    return (this.fieldTarget.getAttribute("accept") || "").startsWith("video/") ? "video/unknown" : "image/unknown"
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
