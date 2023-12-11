import { Controller } from "@hotwired/stimulus"
import { confetti } from "tsparticles-confetti"

export default class extends Controller {
  static values = {
    submissionId: String,
    value: String,
  }

  vote(event) {
    const submissionId = this.submissionIdValue
    const currentValue = this.valueValue
    const value = event.target.dataset.value || event.target.parentElement.dataset.value
    const csrfToken = this.getMetaValue("csrf-token")
    const button = event.target.closest("details") // it's actually a details element, not a button

    fetch(`/submissions/${submissionId}/votes`, {
      method: 'POST',
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify({
        "vote": {
          "value": value,
        }
      }),
    }).then(r => r.text())
      .then(html => Turbo.renderStreamMessage(html))
      .then(() => {
        if (currentValue === value) {
          return
        }

        const defaults = {
          spread: 36,
          ticks: 200,
          gravity: 0,
          decay: 0.94,
          startVelocity: 10,
          origin: {
            x: (button.getBoundingClientRect().left + button.getBoundingClientRect().width / 2) / window.innerWidth,
            y: button.getBoundingClientRect().top / window.innerHeight
          },
          particleCount: 20,
          scalar: 4,
          angle: 120,
        }

        if (value === "love") {
          confetti({
            ...defaults,
            shapes: ["heart"],
            colors: ["FFC0CB", "FF69B4", "FF1493", "C71585"],
          })
        } else if (value === "deny") {
          confetti({
            ...defaults,
            shapes: ["text"],
            shapeOptions: {
              text: {
                value: ["👎"],
              },
            },
          })
        }
      })
  }

  getMetaValue(name) {
    const element = document.head.querySelector(`meta[name="${name}"]`)
    return element?.getAttribute("content")
  }
}
