import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "container", "list" ]
  static values = {
    code: String,
    name: String,
    team: String
  }

  connect() {
    if (localStorage.pastHunts === undefined) {
      localStorage.pastHunts = JSON.stringify({})
    }
    let pastHunts = JSON.parse(localStorage.pastHunts)
    if (this.hasListTarget && Object.keys(pastHunts).length !== 0) {
      Object.keys(pastHunts).forEach(hunt => {
        let opt = document.createElement('option')
        opt.value = hunt
        opt.innerHTML = pastHunts[hunt]
        this.listTarget.appendChild(opt)
      })
    } else {
      if (this.teamValue) {
        pastHunts[this.codeValue] = `${this.teamValue} - ${this.nameValue}`
      } else if(this.nameValue) {
        pastHunts[this.codeValue] = this.nameValue
      }
      localStorage.pastHunts = JSON.stringify(pastHunts)
    }
  }
}
