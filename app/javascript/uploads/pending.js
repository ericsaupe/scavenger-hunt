const HINT = "Will upload when you have signal"

export function showPending(row, file) {
  row.dataset.uploading = "true"
  const slot = row.querySelector("[data-submission-target='slot']")
  if (!slot) {
    return
  }

  slot.replaceChildren()
  slot.classList.remove("border-dashed")
  slot.classList.add("overflow-hidden", "border-marigold", "relative")

  if (file.type.startsWith("image/")) {
    const img = document.createElement("img")
    img.src = URL.createObjectURL(file)
    img.alt = ""
    img.className = "size-full object-cover animate-breathe"
    img.onload = () => URL.revokeObjectURL(img.src)
    slot.appendChild(img)
  } else {
    const spinner = document.createElement("span")
    spinner.className = "loading loading-spinner loading-sm text-marigold"
    slot.appendChild(spinner)
  }
}

export function showQueued(row, file) {
  showPending(row, file)
  delete row.dataset.uploading
  row.dataset.queued = "true"

  const slot = row.querySelector("[data-submission-target='slot']")
  const template = document.getElementById("queued_badge_template")
  if (slot && template) {
    slot.querySelector("img")?.classList.remove("animate-breathe")
    slot.appendChild(template.content.firstElementChild.cloneNode(true))
  }
  setHint(row, HINT, "text-ink-soft")
}

export function showIdle(row) {
  delete row.dataset.uploading
  delete row.dataset.queued
}

export function setHint(row, text, className) {
  const hint = row.querySelector("[data-submission-target='hint']")
  if (!hint) {
    return
  }
  hint.textContent = text
  hint.classList.remove("text-ink-soft", "text-error", "text-sm")
  hint.classList.add(className, "max-w-36", "text-xs", "leading-tight")
}
