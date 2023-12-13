import { Controller } from "@hotwired/stimulus"
import confetti from "canvas-confetti"

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
    }).then(r => {
        if (!r.ok) {
          return Promise.reject(r);
        }

        return r.text()
      })
      .then(html => Turbo.renderStreamMessage(html))
      .then(() => {
        if (currentValue === value) {
          return
        }

        const x = (button.getBoundingClientRect().left + button.getBoundingClientRect().width / 2) / window.innerWidth
        const y = button.getBoundingClientRect().top / window.innerHeight
        const defaults = {
          spread: 80,
          ticks: 75,
          gravity: 0.5,
          decay: 0.94,
          startVelocity: 12,
          origin: {
            x: x,
            y: y
          },
          particleCount: Math.floor(Math.random() * 10) + 10,
          scalar: 4,
          angle: 150,
        }

        if (value === "love") {
          const heart = confetti.shapeFromPath({
            path: 'M167 72c19,-38 37,-56 75,-56 42,0 76,33 76,75 0,76 -76,151 -151,227 -76,-76 -151,-151 -151,-227 0,-42 33,-75 75,-75 38,0 57,18 76,56z',
            matrix: [0.03333333333333333, 0, 0, 0.03333333333333333, -5.566666666666666, -5.533333333333333]
          })
          confetti({
            ...defaults,
            shapes: [heart],
            colors: ["FFC0CB", "FF69B4", "FF1493", "C71585"],
          })
        } else if (value === "deny") {
          const thumbsDown = confetti.shapeFromText({ text: "👎" })
          confetti({
            ...defaults,
            shapes: [thumbsDown],
          })
        }
      })
      .catch(error => {
        console.log(error)
      })
  }

  getMetaValue(name) {
    const element = document.head.querySelector(`meta[name="${name}"]`)
    return element?.getAttribute("content")
  }
}
