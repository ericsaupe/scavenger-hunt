import path from "node:path"
import { fileURLToPath } from "node:url"

const here = path.dirname(fileURLToPath(import.meta.url))

export const BASE_URL = "https://www.scavengerhunt.party"
export const HOSTS = ["www.scavengerhunt.party", "storage.scavengerhunt.party"]
export const PUSH_ADMIN = process.env.PUSH_ADMIN || "http://127.0.0.1:8081"
export const FIXTURES = path.resolve(here, "..", "fixtures")
export const RESULTS = path.resolve(here, "..", "results")
export const PASSWORD = "owls123"
export const FLAG_THRESHOLD = 3

export const TIMELINE = {
  start: 7,
  end: 19,
  unlock: 20,
  show: 21,
  finale: 33,
  handoff: 34,
  flipper: 35,
  done: 36.5
}

export const TEAMS = {
  blue: { name: "Blue Bandits", phones: ["blue-1", "blue-2", "blue-3"] },
  red: { name: "Red Rockets", phones: ["red-1", "red-2", "red-3"] },
  green: { name: "Green Machine", phones: ["green-1", "green-2"] },
  owls: { name: "Owls", phones: ["owls-1", "owls-2"] },
  foxes: { name: "Foxes", phones: ["fox-1", "fox-2"] }
}

export const PUSH = {
  all: ["blue-1", "blue-2", "red-1", "red-2", "green-1", "owls-1"],
  noAnnouncements: ["blue-3", "red-3", "green-2"],
  never: ["owls-2", "fox-1", "fox-2"]
}

export const CHAT_NAMES = {
  "blue-1": "Theo", "blue-2": "Nina", "blue-3": "Marcus",
  "red-1": "Priya", "red-2": "Dev", "red-3": "Lena",
  "green-1": "Maya", "green-2": "Oscar",
  "owls-1": "Sam", "owls-2": "Jo",
  "fox-1": "Jordan", "fox-2": "Kai",
  organizer: "Eric", "organizer-phone": "Eric"
}

export const PHONE = {
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
  userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36"
}

export const LAPTOP = { viewport: { width: 1440, height: 900 } }
export const BIG_SCREEN = { viewport: { width: 1920, height: 1080 } }
