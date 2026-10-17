import fs from "node:fs"
import path from "node:path"
import { FIXTURES } from "../config.js"

const photos = fs.readdirSync(path.join(FIXTURES, "photos")).filter((f) => f.endsWith(".jpg")).sort()
let cursor = 0

export function nextPhoto() {
  const file = photos[cursor % photos.length]
  cursor += 1
  return path.join(FIXTURES, "photos", file)
}

export const CLIP_20 = path.join(FIXTURES, "clip-20s.mp4")
export const CLIP_70 = path.join(FIXTURES, "clip-70s.mp4")
