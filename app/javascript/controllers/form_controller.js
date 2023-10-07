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
