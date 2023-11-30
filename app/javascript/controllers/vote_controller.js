import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    submissionId: String,
  }

  vote(event) {
    const submissionId = this.submissionIdValue
    const value = event.target.dataset.value || event.target.parentElement.dataset.value
    const csrfToken = this.getMetaValue("csrf-token")

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
  }

  getMetaValue(name) {
    const element = document.head.querySelector(`meta[name="${name}"]`)
    return element.getAttribute("content")
  }
}
