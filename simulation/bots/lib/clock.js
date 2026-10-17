export class Clock {
  constructor(speed = 1) {
    this.speed = speed
    this.t0 = null
  }

  start() {
    this.t0 = Date.now()
  }

  minute() {
    return ((Date.now() - this.t0) / 60000) * this.speed
  }

  msUntil(minute) {
    return Math.max(0, (minute / this.speed) * 60000 - (Date.now() - this.t0))
  }

  at(minute) {
    return new Promise((resolve) => setTimeout(resolve, this.msUntil(minute)))
  }

  stamp() {
    return this.minute().toFixed(2)
  }
}

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
