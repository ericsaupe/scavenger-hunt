if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").then(() => {
      if (navigator.serviceWorker.controller) {
        return
      }
      navigator.serviceWorker.addEventListener("controllerchange", () => {
        fetch(window.location.href, { headers: { Accept: "text/html" }, credentials: "same-origin" }).catch(() => {})
      }, { once: true })
    }).catch(() => {})
  })
}

window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault()
  window.deferredInstallPrompt = event
  window.dispatchEvent(new CustomEvent("install-prompt:ready"))
})
