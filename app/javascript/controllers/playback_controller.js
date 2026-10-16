import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "video", "playButton" ]
  static values = {
    follow: Boolean,
    state: String,
    muted: Boolean,
    version: Number,
  }

  stateValueChanged() {
    this.apply()
  }

  mutedValueChanged() {
    this.apply()
  }

  versionValueChanged(version, previous) {
    if (previous !== undefined && version !== previous && this.hasVideoTarget) {
      this.videoTarget.currentTime = 0
    }
    this.apply()
  }

  apply() {
    if (!this.followValue || !this.hasVideoTarget) {
      return
    }

    const video = this.videoTarget
    video.muted = this.mutedValue
    if (this.stateValue === "playing") {
      video.play().catch(() => {
        video.muted = true
        video.play().catch(() => {})
      })
    } else {
      video.pause()
    }
  }

  playLocally() {
    if (!this.hasVideoTarget) {
      return
    }

    const video = this.videoTarget
    video.muted = false
    video.controls = true
    video.play().catch(() => {})
    if (this.hasPlayButtonTarget) {
      this.playButtonTarget.hidden = true
    }
  }
}
