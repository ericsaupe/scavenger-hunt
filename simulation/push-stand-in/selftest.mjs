import assert from "node:assert/strict";
import crypto from "node:crypto";
import https from "node:https";
import net from "node:net";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const webpush = require(path.join(here, "..", "bots", "node_modules", "web-push"));

const vapidKeys = webpush.generateVAPIDKeys();
process.env.VAPID_PUBLIC_KEY = vapidKeys.publicKey;

const { start } = await import("./server.js");
const server = start(0);
await new Promise((resolve) => server.once("listening", resolve));
const { port } = server.address();
const base = `http://127.0.0.1:${port}`;

class PlainTcpAgent extends https.Agent {
  createConnection(options) {
    return net.createConnection({ host: options.host, port: options.port });
  }
}
const agent = new PlainTcpAgent({ keepAlive: false });

const api = async (method, route, body) => {
  const response = await fetch(`${base}${route}`, {
    method,
    headers: body ? { "content-type": "application/json" } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  return { status: response.status, json: text ? JSON.parse(text) : null };
};

const health = await fetch(`${base}/healthz`);
assert.equal(health.status, 200);
assert.equal(await health.text(), "ok");

const { privateKey, publicKey } = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const privateKeyJwk = privateKey.export({ format: "jwk" });
const publicJwk = publicKey.export({ format: "jwk" });
const p256dh = Buffer.concat([
  Buffer.from([4]),
  Buffer.from(publicJwk.x, "base64url"),
  Buffer.from(publicJwk.y, "base64url"),
]).toString("base64url");
const auth = crypto.randomBytes(16).toString("base64url");
const id = `selftest-${crypto.randomBytes(6).toString("hex")}`;

const registered = await api("POST", "/admin/subscriptions", { id, device: "selftest-phone", privateKeyJwk, auth });
assert.equal(registered.status, 201);
assert.equal(registered.json.endpoint, `https://fcm.googleapis.com/fcm/send/${id}`);

const listed = await api("GET", "/admin/subscriptions");
assert.deepEqual(listed.json, [{ id, device: "selftest-phone", expired: false }]);

const subscription = { endpoint: `${base}/fcm/send/${id}`, keys: { p256dh, auth } };
const payload = { title: "hi", body: "there", url: "/x", tag: "t" };
const options = {
  vapidDetails: { subject: "mailto:selftest@example.com", publicKey: vapidKeys.publicKey, privateKey: vapidKeys.privateKey },
  TTL: 60,
  urgency: "high",
  topic: "selftest",
  agent,
};

const sent = await webpush.sendNotification(subscription, JSON.stringify(payload), options);
assert.equal(sent.statusCode, 201);
assert.deepEqual(JSON.parse(sent.body), { ok: true });

const deliveries = await api("GET", "/admin/deliveries");
assert.equal(deliveries.status, 200);
assert.equal(deliveries.json.length, 1);
const [delivery] = deliveries.json;
assert.equal(delivery.id, id);
assert.equal(delivery.device, "selftest-phone");
assert.equal(delivery.ttl, 60);
assert.equal(delivery.urgency, "high");
assert.equal(delivery.topic, "selftest");
assert.equal(delivery.error, null);
assert.equal(delivery.vapidValid, true);
assert.equal(delivery.vapidKeyMatches, true);
assert.deepEqual(delivery.payload, payload);
assert.ok(!Number.isNaN(Date.parse(delivery.receivedAt)));

const otherVapid = webpush.generateVAPIDKeys();
await webpush.sendNotification(subscription, "plain text", {
  ...options,
  vapidDetails: { ...options.vapidDetails, publicKey: otherVapid.publicKey, privateKey: otherVapid.privateKey },
});
const mismatched = (await api("GET", "/admin/deliveries")).json[1];
assert.equal(mismatched.vapidValid, true);
assert.equal(mismatched.vapidKeyMatches, false);
assert.equal(mismatched.payload, "plain text");
assert.match(mismatched.error, /does not match VAPID_PUBLIC_KEY/);

const legacyDetails = webpush.generateRequestDetails(subscription, JSON.stringify(payload), {
  ...options,
  contentEncoding: "aesgcm",
});
assert.match(legacyDetails.headers.Authorization, /^WebPush /);
assert.match(legacyDetails.headers["Crypto-Key"], /p256ecdsa=/);
const legacyResponse = await fetch(subscription.endpoint, {
  method: "POST",
  headers: legacyDetails.headers,
  body: legacyDetails.body,
});
assert.equal(legacyResponse.status, 201);
const legacy = (await api("GET", "/admin/deliveries")).json[2];
assert.equal(legacy.vapidValid, true);
assert.equal(legacy.vapidKeyMatches, true);
assert.equal(legacy.payload, null);
assert.match(legacy.error, /Content-Encoding is aesgcm/);

const wrongSubscriber = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const wrongJwk = wrongSubscriber.publicKey.export({ format: "jwk" });
const wrongP256dh = Buffer.concat([
  Buffer.from([4]),
  Buffer.from(wrongJwk.x, "base64url"),
  Buffer.from(wrongJwk.y, "base64url"),
]).toString("base64url");
await webpush.sendNotification({ ...subscription, keys: { p256dh: wrongP256dh, auth } }, "secret", options);
const undecryptable = (await api("GET", "/admin/deliveries")).json[3];
assert.equal(undecryptable.vapidValid, true);
assert.equal(undecryptable.payload, null);
assert.match(undecryptable.error, /decrypt:/);

const cleared = await api("DELETE", "/admin/deliveries");
assert.equal(cleared.status, 200);
assert.deepEqual((await api("GET", "/admin/deliveries")).json, []);

const unknown = await fetch(`${base}/fcm/send/nobody`, { method: "POST" });
assert.equal(unknown.status, 404);

const expired = await api("POST", "/admin/expire", { id });
assert.equal(expired.status, 200);
assert.deepEqual((await api("GET", "/admin/subscriptions")).json, [{ id, device: "selftest-phone", expired: true }]);

let goneStatus = null;
let goneBody = null;
try {
  await webpush.sendNotification(subscription, JSON.stringify(payload), options);
} catch (error) {
  goneStatus = error.statusCode;
  goneBody = error.body;
}
assert.equal(goneStatus, 410);
assert.equal(goneBody, "");
assert.deepEqual((await api("GET", "/admin/deliveries")).json, []);

agent.destroy();
server.close();
console.log(`selftest passed on port ${port}: decrypted payload ${JSON.stringify(delivery.payload)}, vapidValid=${delivery.vapidValid}, vapidKeyMatches=${delivery.vapidKeyMatches}, expired subscription answered ${goneStatus}`);
