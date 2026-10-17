const http = require("node:http");
const crypto = require("node:crypto");

const subscriptions = new Map();
const deliveries = [];

const b64url = (buf) => Buffer.from(buf).toString("base64url");
const fromB64url = (str) => Buffer.from(String(str).replace(/=+$/, ""), "base64url");

function rawPublicKeyToKeyObject(raw) {
  if (raw.length !== 65 || raw[0] !== 4) throw new Error("public key is not a 65-byte uncompressed P-256 point");
  return crypto.createPublicKey({
    key: { kty: "EC", crv: "P-256", x: b64url(raw.subarray(1, 33)), y: b64url(raw.subarray(33, 65)) },
    format: "jwk",
  });
}

function parseVapid(headers) {
  const authorization = headers.authorization || "";
  let match = authorization.match(/^\s*vapid\s+(.+)$/i);
  if (match) {
    const params = {};
    for (const part of match[1].split(",")) {
      const [name, ...rest] = part.trim().split("=");
      if (name) params[name.trim().toLowerCase()] = rest.join("=").trim().replace(/^"|"$/g, "");
    }
    if (!params.t || !params.k) throw new Error("vapid header missing t or k");
    return { jwt: params.t, key: params.k };
  }
  match = authorization.match(/^\s*WebPush\s+(\S+)\s*$/i);
  if (match) {
    const cryptoKey = headers["crypto-key"] || "";
    const keyMatch = cryptoKey.match(/p256ecdsa=([A-Za-z0-9_-]+)/);
    if (!keyMatch) throw new Error("WebPush authorization without Crypto-Key p256ecdsa");
    return { jwt: match[1], key: keyMatch[1] };
  }
  if (!authorization) throw new Error("missing Authorization header");
  throw new Error("unrecognised Authorization scheme");
}

function verifyVapid(headers) {
  const { jwt, key } = parseVapid(headers);
  const parts = jwt.split(".");
  if (parts.length !== 3) throw new Error("JWT does not have three parts");
  const header = JSON.parse(fromB64url(parts[0]).toString("utf8"));
  const claims = JSON.parse(fromB64url(parts[1]).toString("utf8"));
  if (header.alg !== "ES256") throw new Error(`JWT alg is ${header.alg}, expected ES256`);
  const publicKey = rawPublicKeyToKeyObject(fromB64url(key));
  const signed = crypto.verify(
    "sha256",
    Buffer.from(`${parts[0]}.${parts[1]}`),
    { key: publicKey, dsaEncoding: "ieee-p1363" },
    fromB64url(parts[2])
  );
  if (!signed) throw new Error("JWT signature does not verify against k");
  if (typeof claims.exp !== "number") throw new Error("JWT has no exp claim");
  const now = Math.floor(Date.now() / 1000);
  if (claims.exp <= now) throw new Error("JWT has expired");
  if (claims.exp > now + 24 * 60 * 60) throw new Error("JWT exp is more than 24 hours out");
  if (!claims.aud) throw new Error("JWT has no aud claim");
  const expected = process.env.VAPID_PUBLIC_KEY;
  const keyMatches = expected ? fromB64url(expected).equals(fromB64url(key)) : null;
  return { valid: true, keyMatches, claims };
}

function hkdf(salt, ikm, info, length) {
  return Buffer.from(crypto.hkdfSync("sha256", ikm, salt, info, length));
}

function decryptAes128gcm(body, subscription) {
  if (body.length < 21) throw new Error("body shorter than the aes128gcm header");
  const salt = body.subarray(0, 16);
  const recordSize = body.readUInt32BE(16);
  const idlen = body[20];
  if (body.length < 21 + idlen) throw new Error("body shorter than header plus keyid");
  const senderPublic = body.subarray(21, 21 + idlen);
  if (idlen !== 65) throw new Error(`keyid is ${idlen} bytes, expected a 65-byte sender public key`);
  const ciphertext = body.subarray(21 + idlen);
  if (ciphertext.length > recordSize) throw new Error("more than one record is not supported");
  if (ciphertext.length < 17) throw new Error("record too short to hold a tag and a delimiter");

  const receiverKey = crypto.createPrivateKey({ key: subscription.privateKeyJwk, format: "jwk" });
  const receiverPublic = Buffer.concat([
    Buffer.from([4]),
    fromB64url(subscription.privateKeyJwk.x),
    fromB64url(subscription.privateKeyJwk.y),
  ]);
  const sharedSecret = crypto.diffieHellman({
    privateKey: receiverKey,
    publicKey: rawPublicKeyToKeyObject(senderPublic),
  });
  const ikm = hkdf(
    fromB64url(subscription.auth),
    sharedSecret,
    Buffer.concat([Buffer.from("WebPush: info\0"), receiverPublic, senderPublic]),
    32
  );
  const cek = hkdf(salt, ikm, Buffer.from("Content-Encoding: aes128gcm\0"), 16);
  const nonce = hkdf(salt, ikm, Buffer.from("Content-Encoding: nonce\0"), 12);

  const tag = ciphertext.subarray(ciphertext.length - 16);
  const data = ciphertext.subarray(0, ciphertext.length - 16);
  const decipher = crypto.createDecipheriv("aes-128-gcm", cek, nonce);
  decipher.setAuthTag(tag);
  const padded = Buffer.concat([decipher.update(data), decipher.final()]);

  let end = padded.length - 1;
  while (end >= 0 && padded[end] === 0) end -= 1;
  if (end < 0) throw new Error("record is all padding with no delimiter");
  if (padded[end] !== 2 && padded[end] !== 1) throw new Error(`unexpected padding delimiter 0x${padded[end].toString(16)}`);
  return padded.subarray(0, end).toString("utf8");
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function send(res, status, body, type = "application/json") {
  if (body === undefined || body === "") {
    res.writeHead(status, { "Content-Length": 0 });
    res.end();
    return status;
  }
  const text = typeof body === "string" ? body : JSON.stringify(body);
  res.writeHead(status, { "Content-Type": type, "Content-Length": Buffer.byteLength(text) });
  res.end(text);
  return status;
}

function parseJson(buffer) {
  try {
    return JSON.parse(buffer.toString("utf8"));
  } catch (error) {
    throw Object.assign(new Error("body is not valid JSON"), { status: 400 });
  }
}

function recordPush(req, body, subscription, id) {
  const delivery = {
    id,
    device: subscription.device,
    receivedAt: new Date().toISOString(),
    ttl: req.headers.ttl === undefined ? null : Number(req.headers.ttl),
    urgency: req.headers.urgency || null,
    topic: req.headers.topic || null,
    vapidValid: false,
    vapidKeyMatches: false,
    payload: null,
    error: null,
  };
  const errors = [];
  try {
    const vapid = verifyVapid(req.headers);
    delivery.vapidValid = vapid.valid;
    delivery.vapidKeyMatches = vapid.keyMatches === null ? true : vapid.keyMatches;
    if (vapid.keyMatches === false) errors.push("VAPID k does not match VAPID_PUBLIC_KEY");
  } catch (error) {
    errors.push(`VAPID: ${error.message}`);
  }
  try {
    const encoding = (req.headers["content-encoding"] || "").trim().toLowerCase();
    if (encoding !== "aes128gcm") throw new Error(`Content-Encoding is ${encoding || "missing"}, expected aes128gcm`);
    const plaintext = decryptAes128gcm(body, subscription);
    try {
      delivery.payload = JSON.parse(plaintext);
    } catch (error) {
      delivery.payload = plaintext;
    }
  } catch (error) {
    errors.push(`decrypt: ${error.message}`);
  }
  if (errors.length) delivery.error = errors.join("; ");
  deliveries.push(delivery);
  return delivery;
}

async function handle(req, res) {
  const url = new URL(req.url, "http://localhost");
  const path = url.pathname;
  const body = await readBody(req);

  if (req.method === "GET" && path === "/healthz") return send(res, 200, "ok", "text/plain");

  const pushMatch = path.match(/^\/fcm\/send\/([^/]+)$/);
  if (pushMatch && req.method === "POST") {
    const id = decodeURIComponent(pushMatch[1]);
    const subscription = subscriptions.get(id);
    if (!subscription) return send(res, 404, { error: "unknown subscription" });
    if (subscription.expired) return send(res, 410);
    recordPush(req, body, subscription, id);
    return send(res, 201, { ok: true });
  }

  if (path === "/admin/subscriptions" && req.method === "POST") {
    const { id, device, privateKeyJwk, auth } = parseJson(body);
    if (!id || !privateKeyJwk || !privateKeyJwk.d || !privateKeyJwk.x || !privateKeyJwk.y || !auth) {
      return send(res, 400, { error: "id, device, privateKeyJwk {d,x,y} and auth are required" });
    }
    subscriptions.set(String(id), {
      device: device || null,
      privateKeyJwk: { kty: "EC", crv: "P-256", d: privateKeyJwk.d, x: privateKeyJwk.x, y: privateKeyJwk.y },
      auth,
      expired: false,
    });
    return send(res, 201, { endpoint: `https://fcm.googleapis.com/fcm/send/${encodeURIComponent(String(id))}` });
  }

  if (path === "/admin/subscriptions" && req.method === "GET") {
    const list = [...subscriptions].map(([id, s]) => ({ id, device: s.device, expired: s.expired }));
    return send(res, 200, list);
  }

  if (path === "/admin/expire" && req.method === "POST") {
    const { id } = parseJson(body);
    const subscription = subscriptions.get(String(id));
    if (!subscription) return send(res, 404, { error: "unknown subscription" });
    subscription.expired = true;
    return send(res, 200, { ok: true });
  }

  if (path === "/admin/deliveries" && req.method === "GET") return send(res, 200, deliveries);
  if (path === "/admin/deliveries" && req.method === "DELETE") {
    deliveries.length = 0;
    return send(res, 200, { ok: true });
  }

  return send(res, 404, { error: "not found" });
}

function start(port = Number(process.env.PORT) || 8080) {
  const server = http.createServer((req, res) => {
    handle(req, res)
      .catch((error) => send(res, error.status || 500, { error: error.message }))
      .then((status) => console.log(`${req.method} ${req.url} ${status}`));
  });
  server.listen(port);
  return server;
}

if (require.main === module) {
  const server = start();
  server.on("listening", () => console.log(`push stand-in listening on ${server.address().port}`));
}

module.exports = { start };
