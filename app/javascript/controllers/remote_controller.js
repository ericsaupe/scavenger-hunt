import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "items" ]
  static values = {
    url: String,
    playbackUrl: String,
    playing: Boolean,
    video: Boolean,
  }

  connect() {
    this.inFlight = false
    this.onKeydown = (event) => {
      if (event.target.closest("input, textarea")) {
        return
      }
      if (event.key === "ArrowRight") {
        event.preventDefault()
        this.next()
      } else if (event.key === "ArrowLeft") {
        event.preventDefault()
        this.previous()
      } else if (event.key === " " && this.videoValue && !event.target.closest("button")) {
        event.preventDefault()
        this.toggle()
      }
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  next() {
    this.send(this.urlValue, { direction: "next" })
  }

  previous() {
    this.send(this.urlValue, { direction: "previous" })
  }

  jump(event) {
    this.closeItems()
    this.send(this.urlValue, { slide: event.currentTarget.dataset.slide })
  }

  openItems() {
    if (this.hasItemsTarget && !this.itemsTarget.open) {
      this.itemsTarget.showModal()
    }
  }

  closeItems() {
    if (this.hasItemsTarget && this.itemsTarget.open) {
      this.itemsTarget.close()
    }
  }

  play() {
    this.playback("play")
  }

  pause() {
    this.playback("pause")
  }

  toggle() {
    this.playingValue ? this.pause() : this.play()
  }

  replay() {
    this.playback("replay")
  }

  mute() {
    this.playback("mute")
  }

  unmute() {
    this.playback("unmute")
  }

  playback(action) {
    this.send(this.playbackUrlValue, { playback: { action } })
  }

  async send(url, body) {
    if (this.inFlight) {
      return
    }

    this.inFlight = true
    this.buttonTargets.forEach(button => button.disabled = true)
    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.head.querySelector(`meta[name="csrf-token"]`)?.getAttribute("content"),
        },
        body: JSON.stringify(body),
      })
      if (!response.ok) {
        console.error(`Remote command failed with status ${response.status}`)
      }
    } catch (error) {
      console.error(error)
    } finally {
      this.inFlight = false
      this.buttonTargets.forEach(button => button.disabled = false)
    }
  }
}
