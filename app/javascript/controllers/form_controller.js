import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = [ "timezone", "endConfig", "datetime" ]

  connect() {
    if (this.hasTimezoneTarget) {
      this.timezoneTarget.value = Intl.DateTimeFormat().resolvedOptions().timeZone
    }

    // flatpickr swaps itself for the native datetime-local control on phones and
    // draws a calendar everywhere else, so desktop Safari gets a real picker too.
    this.pickers = this.datetimeTargets.map(input => flatpickr(input, {
      enableTime: true,
      altInput: true,
      altFormat: "D, M j, Y h:i K",
      dateFormat: "Y-m-d H:i",
      minDate: "today",
      onChange: () => this.syncEndFields()
    }))

    this.syncEndFields()
  }

  disconnect() {
    this.pickers?.forEach(picker => picker.destroy())
  }

  toggleEndFields() {
    this.syncEndFields()
  }

  syncEndFields() {
    const ends = this.datetimeTargets.find(input => input.name.includes("ends_at"))
    this.endConfigTargets.forEach(target => {
      target.classList.toggle("hidden", !ends?.value)
    })
  }
}
