import crypto from "node:crypto"
import { PUSH_ADMIN } from "../config.js"

export function makeSubscriberKeys() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" })
  const pub = publicKey.export({ format: "jwk" })
  const p256dh = Buffer.concat([Buffer.from([4]), Buffer.from(pub.x, "base64url"), Buffer.from(pub.y, "base64url")]).toString("base64url")
  return {
    p256dh,
    auth: crypto.randomBytes(16).toString("base64url"),
    privateKeyJwk: privateKey.export({ format: "jwk" })
  }
}

async function admin(method, pathname, body) {
  const response = await fetch(PUSH_ADMIN + pathname, {
    method,
    headers: { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body)
  })
  if (!response.ok) throw new Error(`push stand-in ${method} ${pathname} -> ${response.status}`)
  const text = await response.text()
  return text ? JSON.parse(text) : null
}

export async function registerSubscriber(device) {
  const keys = makeSubscriberKeys()
  const id = `${device}-${crypto.randomBytes(6).toString("hex")}`
  const { endpoint } = await admin("POST", "/admin/subscriptions", { id, device, privateKeyJwk: keys.privateKeyJwk, auth: keys.auth })
  return { id, endpoint, p256dh: keys.p256dh, auth: keys.auth }
}

export const expireSubscriber = (id) => admin("POST", "/admin/expire", { id })
export const deliveries = () => admin("GET", "/admin/deliveries")
export const clearDeliveries = () => admin("DELETE", "/admin/deliveries")

export function pushStubScript({ endpoint, p256dh, auth }) {
  return `(() => {
    const subscription = {
      endpoint: ${JSON.stringify(endpoint)},
      expirationTime: null,
      options: { userVisibleOnly: true },
      toJSON() { return { endpoint: this.endpoint, expirationTime: null, keys: { p256dh: ${JSON.stringify(p256dh)}, auth: ${JSON.stringify(auth)} } } },
      unsubscribe() { window.__simSubscribed = false; return Promise.resolve(true) }
    }
    let permission = "default"
    try {
      Object.defineProperty(Notification, "permission", { get: () => permission, configurable: true })
      Notification.requestPermission = () => { permission = "granted"; return Promise.resolve("granted") }
    } catch (e) {}
    const manager = {
      getSubscription: () => Promise.resolve(window.__simSubscribed ? subscription : null),
      subscribe: () => { window.__simSubscribed = true; return Promise.resolve(subscription) },
      permissionState: () => Promise.resolve(permission)
    }
    if (window.ServiceWorkerRegistration) {
      Object.defineProperty(ServiceWorkerRegistration.prototype, "pushManager", { get: () => manager, configurable: true })
    }
    try { localStorage.setItem("pushPromptPending", "true") } catch (e) {}
  })()`
}
