import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "video", "playButton", "soundButton" ]
  static values = {
    follow: Boolean,
    state: String,
    muted: Boolean,
    version: Number,
  }

  connect() {
    if (this.hasVideoTarget && this.hasPlayButtonTarget) {
      this.videoTarget.addEventListener("play", () => this.playButtonTarget.hidden = true)
    }
  }

  stateValueChanged() {
    this.apply()
  }

  mutedValueChanged() {
    this.apply()
  }

  versionValueChanged(version, previous) {
    if (this.followValue && previous !== undefined && version !== previous && this.hasVideoTarget) {
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
      video.play().catch(error => this.playBlocked(error))
    } else {
      video.pause()
    }
    if (this.hasSoundButtonTarget && this.mutedValue) {
      this.soundButtonTarget.hidden = true
    }
  }

  playBlocked(error) {
    if (error.name !== "NotAllowedError" || this.stateValue !== "playing") {
      return
    }

    const video = this.videoTarget
    if (!video.muted) {
      video.muted = true
      video.play().catch(() => {})
    }
    if (this.hasSoundButtonTarget) {
      this.soundButtonTarget.hidden = false
    }
  }

  enableSound() {
    const video = this.videoTarget
    video.muted = false
    video.play().catch(error => this.playBlocked(error))
    if (this.hasSoundButtonTarget) {
      this.soundButtonTarget.hidden = true
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
