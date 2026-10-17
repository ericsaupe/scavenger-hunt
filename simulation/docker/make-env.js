const crypto = require("crypto")
const fs = require("fs")
const path = require("path")

const b64url = (buffer) => Buffer.from(buffer).toString("base64url")
const { privateKey, publicKey } = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" })
const publicRaw = publicKey.export({ format: "jwk" })
const privateJwk = privateKey.export({ format: "jwk" })
const vapidPublic = b64url(Buffer.concat([Buffer.from([4]), Buffer.from(publicRaw.x, "base64url"), Buffer.from(publicRaw.y, "base64url")]))
const vapidPrivate = privateJwk.d

const env = [
  `SECRET_KEY_BASE=${crypto.randomBytes(64).toString("hex")}`,
  `VAPID_PUBLIC_KEY=${vapidPublic}`,
  `VAPID_PRIVATE_KEY=${vapidPrivate}`,
  "VAPID_SUBJECT=mailto:sim@scavengerhunt.party",
  ""
].join("\n")

const target = path.join(__dirname, "..", ".env")
if (fs.existsSync(target) && !process.argv.includes("--force")) {
  console.log(`${target} already exists, keeping it`)
} else {
  fs.writeFileSync(target, env)
  console.log(`wrote ${target}`)
}
