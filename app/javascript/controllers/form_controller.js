import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = [ "timezone", "endConfig" ]

  connect() {
    const config = {
      enableTime: true,
      altInput: true,
      altFormat: "F j, Y h:i K",
      dateFormat: "Y-m-d H:i",
      enable: [
        function(date) {
          let today = new Date()
          today.setHours(0,0,0,0)
          return date >= today
        }
      ]
    }
    flatpickr(".datetime", config)

    if (this.hasTimezoneTarget) {
      this.timezoneTarget.value = Intl.DateTimeFormat().resolvedOptions().timeZone
    }
  }

  toggleSwitch(event) {
    let toggle = event.target
    let circle = toggle.querySelector('.circle')
    let x = toggle.querySelector('.x')
    let check = toggle.querySelector('.check')
    let checkbox = toggle.parentNode.querySelector('input[type="checkbox"]')
    if (toggle.classList.contains("bg-gray-200")) {
      // Switch toggle on
      checkbox.checked = true
      toggle.setAttribute('aria-checked', true)
      toggle.value = true
      toggle.classList.remove("bg-gray-200")
      toggle.classList.add("bg-indigo-600")

      circle.classList.remove("translate-x-0")
      circle.classList.add("translate-x-5")

      x.classList.remove("opacity-100", "ease-in", "duration-200")
      x.classList.add("opacity-0", "ease-out", "duration-100")

      check.classList.remove("opacity-0", "ease-out", "duration-100")
      check.classList.add("opacity-100", "ease-in", "duration-200")
    } else {
      // Switch toggle off
      checkbox.checked = false
      toggle.setAttribute('aria-checked', false)
      toggle.value = false
      toggle.classList.add("bg-gray-200")
      toggle.classList.remove("bg-indigo-600")

      circle.classList.add("translate-x-0")
      circle.classList.remove("translate-x-5")

      x.classList.add("opacity-100", "ease-in", "duration-200")
      x.classList.remove("opacity-0", "ease-out", "duration-100")

      check.classList.add("opacity-0", "ease-out", "duration-100")
      check.classList.remove("opacity-100", "ease-in", "duration-200")
    }
  }

  toggleEndFields(event) {
    if(event.target.value) {
      this.endConfigTargets.forEach(target => {
        target.classList.remove("hidden")
      })
    } else {
      this.endConfigTargets.forEach(target => {
        target.classList.add("hidden")
      })
    }
  }
}
