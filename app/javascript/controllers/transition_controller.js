import { Controller } from "@hotwired/stimulus"

const DECODE_TIMEOUT = 3000
const EXIT_TIMEOUT = 800

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.onBeforeMorph = (event) => this.beforeMorph(event)
    this.onMorph = () => this.enter()
    this.element.addEventListener("turbo:before-morph-element", this.onBeforeMorph)
    document.addEventListener("turbo:morph", this.onMorph)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-element", this.onBeforeMorph)
    document.removeEventListener("turbo:morph", this.onMorph)
  }

  beforeMorph(event) {
    const { newElement } = event.detail
    if (event.target.id !== "current_slide" || !newElement) {
      return
    }
    const outgoing = event.target.querySelector("[data-print]")
    const incoming = newElement.querySelector("[data-print]")
    if (!outgoing || !incoming || outgoing.id === incoming.id) {
      return
    }
    incoming.classList.add("print-pending")
    this.exit(outgoing)
  }

  exit(print) {
    const clone = print.cloneNode(true)
    clone.removeAttribute("data-print")
    clone.removeAttribute("data-controller")
    clone.removeAttribute("id")
    clone.querySelectorAll("[id]").forEach((element) => element.removeAttribute("id"))
    const { left, top } = this.offsetWithin(print)
    Object.assign(clone.style, {
      position: "absolute",
      left: `${left}px`,
      top: `${top}px`,
      width: `${print.offsetWidth}px`,
      height: `${print.offsetHeight}px`,
      margin: "0",
      maxWidth: "none",
    })
    clone.classList.add("print-exit")
    clone.addEventListener("animationend", () => clone.remove(), { once: true })
    setTimeout(() => clone.remove(), EXIT_TIMEOUT)
    this.overlayTarget.append(clone)
  }

  async enter() {
    const print = this.element.querySelector("[data-print].print-pending")
    if (!print) {
      return
    }
    await Promise.race([this.decoded(print), new Promise((resolve) => setTimeout(resolve, DECODE_TIMEOUT))])
    if (print.isConnected) {
      print.classList.replace("print-pending", "print-enter")
    }
  }

  decoded(print) {
    return Promise.allSettled(Array.from(print.querySelectorAll("img"), (img) => img.decode()))
  }

  offsetWithin(print) {
    let left = 0
    let top = 0
    for (let node = print; node && node !== this.element; node = node.offsetParent) {
      left += node.offsetLeft
      top += node.offsetTop
    }
    return { left, top }
  }
}
