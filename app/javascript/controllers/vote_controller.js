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
    const button = event.currentTarget
    if (button.disabled) {
      return
    }
    button.disabled = true
    const value = button.dataset.value
    const csrfToken = this.getMetaValue("csrf-token")
    const rect = button.getBoundingClientRect()

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
      .then(html => {
        if (!this.element.isConnected || this.submissionIdValue !== submissionId) {
          return
        }

        Turbo.renderStreamMessage(html)
        if (currentValue === value) {
          return
        }

        const defaults = {
          spread: 80,
          ticks: 75,
          gravity: 0.5,
          decay: 0.94,
          startVelocity: 12,
          origin: {
            x: (rect.left + rect.width / 2) / window.innerWidth,
            y: rect.top / window.innerHeight
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
          const flag = confetti.shapeFromPath({
            path: 'M3 2.25a.75.75 0 01.75.75v.54l1.838-.46a9.75 9.75 0 016.725.738l.108.054a8.25 8.25 0 005.58.652l3.109-.732a.75.75 0 01.917.81 47.784 47.784 0 00.005 10.337.75.75 0 01-.574.812l-3.114.733a9.75 9.75 0 01-6.594-.77l-.108-.054a8.25 8.25 0 00-5.69-.625l-2.202.55V21a.75.75 0 01-1.5 0V3a.75.75 0 01.75-.75z'
          })
          confetti({
            ...defaults,
            shapes: [flag],
            colors: ["FFB703", "FFC533", "FFD166"],
          })
        }
      })
      .catch(error => {
        console.error(error)
      })
      .finally(() => {
        button.disabled = false
      })
  }

  getMetaValue(name) {
    const element = document.head.querySelector(`meta[name="${name}"]`)
    return element?.getAttribute("content")
  }
}
