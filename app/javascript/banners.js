export function addBanner(message, { actionLabel, onAction } = {}) {
  const template = document.getElementById("banner_template")
  const flash = document.getElementById("flash")
  if (!template || !flash) {
    return
  }

  const banner = template.content.firstElementChild.cloneNode(true)
  banner.querySelector("[data-banner-message]").textContent = message
  const action = banner.querySelector("[data-banner-action]")
  if (actionLabel) {
    action.textContent = actionLabel
    action.addEventListener("click", onAction)
    banner.dataset.flashStickyValue = "true"
  } else {
    action.remove()
    banner.dataset.flashStickyValue = "false"
  }
  flash.appendChild(banner)
}
