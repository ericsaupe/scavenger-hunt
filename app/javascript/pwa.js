if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch(() => {})
  })
}

window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault()
  window.deferredInstallPrompt = event
  window.dispatchEvent(new CustomEvent("install-prompt:ready"))
})
