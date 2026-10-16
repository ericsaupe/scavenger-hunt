const DISMISSED_KEY = "pushPromptDismissed"
const PENDING_KEY = "pushPromptPending"
const OFF_PREFIX = "pushOff:"

function read(key) {
  try {
    return localStorage.getItem(key)
  } catch (error) {
    return null
  }
}

function write(key, value) {
  try {
    if (value === null) {
      localStorage.removeItem(key)
    } else {
      localStorage.setItem(key, value)
    }
  } catch (error) {
  }
}

export function supported() {
  return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
}

export function installed() {
  return window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true
}

export function permission() {
  return supported() ? Notification.permission : "denied"
}

export const prompt = {
  dismissed: () => read(DISMISSED_KEY) === "true",
  dismiss: () => write(DISMISSED_KEY, "true"),
  pending: () => read(PENDING_KEY) === "true",
  markPending: () => write(PENDING_KEY, "true"),
  clearPending: () => write(PENDING_KEY, null)
}

export const optOut = {
  active: (code) => read(OFF_PREFIX + code) === "true",
  set: (code) => write(OFF_PREFIX + code, "true"),
  clear: (code) => write(OFF_PREFIX + code, null)
}

export async function currentSubscription() {
  const registration = await navigator.serviceWorker.ready
  return registration.pushManager.getSubscription()
}

export async function subscribe(publicKey) {
  const registration = await navigator.serviceWorker.ready
  const existing = await registration.pushManager.getSubscription()
  if (existing) return existing

  return registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: decodeKey(publicKey) })
}

export async function unsubscribe() {
  const subscription = await currentSubscription()
  await subscription?.unsubscribe()
}

export function send(url, method, body) {
  return fetch(url, {
    method,
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": document.head.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    },
    credentials: "same-origin",
    body: body === undefined ? undefined : JSON.stringify(body)
  }).then((response) => {
    if (!response.ok) {
      throw new Error(`Push subscription request failed with status ${response.status}`)
    }
    return response
  })
}

function decodeKey(base64url) {
  const padding = "=".repeat((4 - (base64url.length % 4)) % 4)
  const base64 = (base64url + padding).replace(/-/g, "+").replace(/_/g, "/")
  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0))
}
