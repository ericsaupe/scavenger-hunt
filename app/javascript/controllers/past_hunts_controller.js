import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "container", "list" ]
  static values = {
    code: String,
    name: String,
    team: String
  }

  connect() {
    // Initialize localStorage
    if (localStorage.pastHunts === undefined) {
      localStorage.pastHunts = JSON.stringify({})
    }

    let pastHunts = JSON.parse(localStorage.pastHunts)
    // Handle the list of past hunts
    if (this.hasListTarget && Object.keys(pastHunts).length !== 0) {
      Object.keys(pastHunts).forEach(hunt => {
        // skip empty hunts or hunts that are already on the list
        if (!hunt || this.listTarget.querySelector(`[value="${hunt}"]`)) {
          return
        }
        let opt = document.createElement('option')
        opt.value = hunt
        opt.innerHTML = pastHunts[hunt]
        this.listTarget.appendChild(opt)
      })
    } else {
      // Handle storing joined hunts
      if (this.teamValue) {
        pastHunts[this.codeValue] = `${this.teamValue} - ${this.nameValue}`
      } else if(this.nameValue) {
        pastHunts[this.codeValue] = this.nameValue
      }
      localStorage.pastHunts = JSON.stringify(pastHunts)
    }
  }
}
