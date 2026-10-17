import { Turbo } from "@hotwired/turbo-rails"
import { entries, remove } from "./queue"
import { uploadWithRetries } from "./direct_upload"
import { setHint, showIdle, showQueued } from "./pending"

const UPLOAD_REFUSED = "This photo couldn't be uploaded"

let draining = null
const refusals = new Map()

export function drain() {
  if (!draining) {
    draining = run().finally(() => { draining = null })
  }
  return draining
}

export function restoreRefusals() {
  refusals.forEach((message, submissionId) => {
    const row = document.getElementById(`submission_${submissionId}`)
    if (row && !row.dataset.found) {
      setHint(row, message, "text-error")
    }
  })
}

export function registerSync() {
  if (!("serviceWorker" in navigator)) {
    return
  }
  navigator.serviceWorker.ready
    .then((registration) => registration.sync?.register("upload-queue"))
    .catch(() => {})
}

async function run() {
  if (!navigator.onLine) {
    return
  }

  const attempted = new Set()
  while (true) {
    const pending = (await entries()).filter((entry) => !attempted.has(entry.id))
    if (pending.length === 0) {
      return
    }
    for (const entry of pending) {
      attempted.add(entry.id)
      if (!await send(entry)) {
        return
      }
    }
  }
}

async function send(entry) {
  const row = document.getElementById(`submission_${entry.submissionId}`)
  if (row) {
    delete row.dataset.queued
    row.dataset.uploading = "true"
  }

  let response
  try {
    const field = row?.querySelector("[data-direct-upload-url]")
    const blob = await uploadWithRetries(entry.file, field?.dataset.directUploadUrl || entry.directUploadUrl)
    response = await fetch(entry.updateUrl, {
      method: "PATCH",
      headers: { Accept: "text/vnd.turbo-stream.html" },
      body: formDataFor(entry, blob.signed_id)
    })
  } catch (e) {
    if (row) showQueued(row, entry.file)
    return false
  }

  if (response.ok || response.status === 422) {
    await remove(entry.id)
    const html = await response.text()
    Turbo.renderStreamMessage(html)
    if (response.status === 422) {
      await noteRefusal(entry, html)
    }
    document.dispatchEvent(new CustomEvent("uploads:landed"))
    return true
  }

  if (response.status < 500) {
    await remove(entry.id)
    refusals.set(entry.submissionId, UPLOAD_REFUSED)
    if (row) {
      showIdle(row)
      setHint(row, UPLOAD_REFUSED, "text-error")
    }
    return true
  }

  if (row) showQueued(row, entry.file)
  return false
}

function formDataFor(entry, signedId) {
  const body = new FormData()
  body.append("submission[photo]", signedId)
  body.append("submission[captured_at]", entry.capturedAt)
  if (!entry.retake) {
    body.append("submission[keep_existing]", "1")
  }
  return body
}

async function noteRefusal(entry, html) {
  await new Promise((resolve) => requestAnimationFrame(resolve))
  const row = document.getElementById(`submission_${entry.submissionId}`)
  const templates = new DOMParser().parseFromString(html, "text/html").querySelectorAll("template")
  const message = Array.from(templates, (template) => template.content.querySelector("[data-banner-message]")).find(Boolean)?.textContent
  if (!message) {
    return
  }
  refusals.set(entry.submissionId, message)
  if (row) {
    showIdle(row)
    setHint(row, message, "text-error")
  }
}
