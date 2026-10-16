import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "list", "empty" ]
  static values = {
    code: String,
    name: String,
    team: String
  }

  connect() {
    let pastHunts = {}
    try {
      pastHunts = JSON.parse(localStorage.pastHunts || "{}")
    } catch (e) {
      pastHunts = {}
    }

    if (this.hasListTarget) {
      this.renderList(pastHunts)
    } else if (this.codeValue) {
      if (this.teamValue) {
        pastHunts[this.codeValue] = `${this.teamValue} - ${this.nameValue}`
      } else if (this.nameValue) {
        pastHunts[this.codeValue] = this.nameValue
      }
      try {
        localStorage.pastHunts = JSON.stringify(pastHunts)
      } catch (e) {
        return
      }
    }
  }

  renderList(pastHunts) {
    const codes = Object.keys(pastHunts).filter(code => /^[A-Z]{1,5}$/.test(code))
    if (codes.length === 0) {
      return
    }

    codes.reverse().forEach(code => {
      if (this.listTarget.querySelector(`[data-code="${code}"]`)) {
        return
      }
      const item = document.createElement("li")
      item.innerHTML = `
        <a href="/scavenger_hunts/${code}" class="row-tap" data-code="${code}">
          <span class="grid size-12 shrink-0 place-items-center rounded-xl bg-base-200 font-mono text-xs font-bold tracking-widest">${code}</span>
          <span class="grow truncate font-semibold"></span>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="size-5 shrink-0 text-ink-soft" fill="none" stroke="currentColor" stroke-width="1.75" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
        </a>`
      item.querySelector("span.grow").textContent = pastHunts[code]
      this.listTarget.appendChild(item)
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.add("hidden")
    }
  }
}
