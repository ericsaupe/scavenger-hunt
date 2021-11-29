import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "container", "countdown" ]
  static values = {
    startsAt: Number,
    endsAt: Number
  }

  connect() {
    this.startCountdown()
  }

  startCountdown() {
    const containerTarget = this.containerTarget
    const countdownTarget = this.countdownTarget
    const startsAt = this.startsAtValue
    const endsAt = this.endsAtValue

    console.log(startsAt, endsAt)

    // Update the count down every 1 second
    let x = setInterval(function() {
      // Pick which date is the upcoming one. If we are before the start date we use that, otherwise we use the end date.
      let countdownDate = new Date(startsAt > Date.now() ? startsAt : endsAt)
      let explanation
      if (startsAt && startsAt > Date.now()) {
        explanation = "Starts in "
        containerTarget.classList.add("bg-blue-500")
        containerTarget.classList.remove("bg-green-500", "bg-red-500")
      } else if (endsAt && endsAt > Date.now()) {
        explanation = "Ends in "
        containerTarget.classList.add("bg-green-500")
        containerTarget.classList.remove("bg-blue-500", "bg-red-500")
      }
      // Get today's date and time
      let now = new Date().getTime()
      // Find the distance between now and the count down date
      let distance = countdownDate - now
      // Time calculations for days, hours, minutes and seconds
      let days = Math.floor(distance / (1000 * 60 * 60 * 24))
      let hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
      let minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60))
      let seconds = Math.floor((distance % (1000 * 60)) / 1000)
      countdownTarget.innerHTML = `${explanation}${days}d ${hours}h ${minutes}m ${seconds}s`
      // If the count down is finished, write some text
      if (distance < 0) {
        clearInterval(x)
        countdownTarget.innerHTML = "This scavenger hunt has ended. No more submissions will be accepted."
        containerTarget.classList.add("bg-red-500")
        containerTarget.classList.remove("bg-blue-500", "bg-green-500")
      }
    }, 1000)
  }
}
