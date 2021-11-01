import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "closedIcon", "openIcon", "menu" ]

  toggleMenu() {
    console.log('menu')
    if (this.menuTarget.classList.contains('hidden')) {
      this.closedIconTarget.classList.remove('block')
      this.closedIconTarget.classList.add('hidden')
      this.openIconTarget.classList.remove('hidden')
      this.openIconTarget.classList.add('block')
      this.menuTarget.classList.remove('hidden')
    } else {
      this.openIconTarget.classList.remove('block')
      this.openIconTarget.classList.add('hidden')
      this.closedIconTarget.classList.remove('hidden')
      this.closedIconTarget.classList.add('block')
      this.menuTarget.classList.add('hidden')
    }
  }
}
