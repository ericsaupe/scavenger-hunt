import { Controller } from "@hotwired/stimulus"

const FIT = "(min-width: 640px)"
const PASSES = 3
const FOOTER_GAP = 16

export default class extends Controller {
  static targets = ["media", "caption"]

  connect() {
    this.refit = () => this.fit()
    this.footer = document.querySelector("[data-fit-footer]")
    this.observer = new ResizeObserver(this.refit)
    this.observer.observe(this.element.parentElement)
    this.observer.observe(this.captionTarget)
    if (this.footer) {
      this.observer.observe(this.footer)
    }
    document.addEventListener("turbo:morph", this.refit)
    this.fit()
  }

  disconnect() {
    this.observer.disconnect()
    this.bindMedia(null)
    document.removeEventListener("turbo:morph", this.refit)
  }

  fit() {
    const card = this.element
    const box = this.mediaTarget
    const stage = card.parentElement
    this.bindMedia(box.querySelector("img, video"))
    if (!window.matchMedia(FIT).matches) {
      card.style.width = box.style.width = box.style.height = stage.style.paddingBottom = ""
      return
    }

    if (this.footer) {
      stage.style.paddingBottom = `${this.footer.offsetHeight + FOOTER_GAP}px`
    }
    const stageStyle = getComputedStyle(stage)
    const cardStyle = getComputedStyle(card)
    const frameX = parseFloat(cardStyle.paddingLeft) + parseFloat(cardStyle.paddingRight)
    const frameY = parseFloat(cardStyle.paddingTop) + parseFloat(cardStyle.paddingBottom)
    const stageWidth = stage.clientWidth - parseFloat(stageStyle.paddingLeft) - parseFloat(stageStyle.paddingRight)
    const stageHeight = stage.clientHeight - parseFloat(stageStyle.paddingTop) - parseFloat(stageStyle.paddingBottom)
    const tilt = Math.abs(parseFloat(cardStyle.getPropertyValue("--tilt")) || 0) * Math.PI / 180
    const cos = Math.cos(tilt)
    const sin = Math.sin(tilt)
    const ratio = this.ratio()

    let captionHeight = null
    for (let pass = 0; pass < PASSES; pass++) {
      const measured = this.captionTarget.offsetHeight + parseFloat(getComputedStyle(this.captionTarget).marginTop)
      if (measured === captionHeight) {
        break
      }
      captionHeight = measured
      const below = frameY + captionHeight
      const byHeight = (stageHeight - below * cos - frameX * sin) / (cos + ratio * sin)
      const byWidth = (stageWidth - frameX * cos - below * sin) / (ratio * cos + sin)
      const height = Math.floor(Math.min(byHeight, byWidth))
      const width = Math.floor(height * ratio)
      box.style.width = `${width}px`
      box.style.height = `${height}px`
      card.style.width = `${width + frameX}px`
    }
  }

  bindMedia(media) {
    if (media === this.media) {
      return
    }
    this.media?.removeEventListener("load", this.refit)
    this.media?.removeEventListener("loadedmetadata", this.refit)
    this.media = media
    this.media?.addEventListener("load", this.refit)
    this.media?.addEventListener("loadedmetadata", this.refit)
  }

  ratio() {
    const media = this.media
    const natural = media instanceof HTMLVideoElement
      ? media.videoWidth / media.videoHeight
      : media?.naturalWidth / media?.naturalHeight
    if (natural > 0 && Number.isFinite(natural)) {
      return natural
    }
    const [width, height] = this.mediaTarget.style.aspectRatio.split("/").map(parseFloat)
    return width > 0 && height > 0 ? width / height : 4 / 3
  }
}
