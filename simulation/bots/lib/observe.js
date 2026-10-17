export const OBSERVER_SCRIPT = `(() => {
  if (window.__simObserving) return
  window.__simObserving = true
  const seen = new Set()
  let reactions = 0
  const report = (kind, key, extra) => {
    const id = kind + ":" + key
    if (seen.has(id)) return
    seen.add(id)
    window.__simSeen(kind, String(key), Date.now(), extra === undefined ? null : extra)
  }
  const text = (el) => (el ? el.textContent.replace(/\\s+/g, " ").trim() : "")
  const scan = () => {
    document.querySelectorAll('#teams input[type="radio"][name="team_id"]').forEach((el) => report("team", "team_" + el.value, text(el.closest("label"))))
    document.querySelectorAll('li[id^="submission_"][data-found]').forEach((el) => {
      report("found", el.id)
      const video = el.querySelector('[data-video="true"]')
      if (video) {
        if (el.querySelector('[data-testid="processing"]')) report("processing", el.id)
        else report("playback", el.id)
      }
    })
    document.querySelectorAll('li[id^="submission_"] [data-testid="queued-badge"]').forEach((el) => report("queued", el.closest("li").id))
    document.querySelectorAll('[data-testid="chat-message"]').forEach((el) => {
      report("chat", el.dataset.messageId, { announcement: "announcement" in el.dataset, text: text(el.querySelector(".message-bubble")) })
      if ("removed" in el.dataset) report("removed", el.dataset.messageId)
    })
    document.querySelectorAll('[data-testid="chat-pinned"] [data-message-id]').forEach((el) => report("pinned", el.dataset.messageId))
    const unread = document.querySelector('[data-testid="chat-unread"]')
    if (unread && !unread.hidden && text(unread)) report("unread", text(unread))
    const progress = document.querySelector('[data-testid="progress"]')
    const slide = document.querySelector("#current_slide")
    if (progress && slide) {
      const key = (slide.querySelector("[data-print]") || slide).id || text(progress)
      report("slide", key, text(progress))
    }
    const playback = document.querySelector('[data-controller~="playback"]')
    if (playback) {
      const d = playback.dataset
      report("playback-state", d.playbackStateValue + ":" + d.playbackVersionValue + ":" + d.playbackMutedValue)
    }
    document.querySelectorAll('[data-testid="screen-chat-list"] [data-message-id]').forEach((el) => report("screenchat", el.dataset.messageId))
    const screenChat = document.querySelector('[data-testid="screen-chat"]')
    if (screenChat) report("screenchat-mode", screenChat.dataset.screenChatModeValue + ":" + (getComputedStyle(screenChat).display === "none" ? "hidden" : "shown"))
    const loves = document.querySelector('[data-testid="love-count"]')
    if (loves && slide) report("loves", slide.id + ":" + (slide.querySelector("[data-print]") || slide).id + ":" + text(loves))
    const flags = document.querySelector('[data-testid="flag-count"]')
    if (flags && slide) report("flags", (slide.querySelector("[data-print]") || slide).id + ":" + text(flags))
    document.querySelectorAll("table tbody tr").forEach((row) => {
      const cells = row.querySelectorAll("td")
      if (cells.length >= 3) report("score", text(cells[1]) + ":" + text(cells[cells.length - 1]))
    })
    const live = document.querySelector('[data-testid="live-pill"]')
    if (live) report("live-pill", text(live))
    const finale = document.querySelector('[data-testid="finale"]')
    if (finale) report("finale", text(finale.querySelector('[data-testid="winner-name"]')))
    const pending = document.querySelector('[data-testid="pending-uploads"]')
    if (pending) report("pending-uploads", text(pending))
    document.querySelectorAll('#flash > *').forEach((el) => report("banner", text(el)))
    const notice = document.querySelector('[id^="chat_notice_"]')
    if (notice && text(notice)) report("chat-notice", text(notice))
    const pill = document.querySelector('[data-testid="chat-pill"]')
    report("chat-pill", pill ? "present" : "absent")
    const presenting = document.querySelector('[data-testid="presenting"]')
    if (presenting) report("presenting", text(presenting))
  }
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === 1 && node.matches && node.matches('[data-testid="reaction"]')) {
          reactions += 1
          report("reaction", reactions, node.dataset.reactionKind)
        }
      }
    }
    scan()
  })
  observer.observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-found", "data-playback-state-value", "data-playback-version-value", "data-playback-muted-value", "class", "data-screen-chat-mode-value", "data-removed", "hidden"] })
  document.addEventListener("DOMContentLoaded", scan)
  document.addEventListener("turbo:load", scan)
  document.addEventListener("turbo:render", scan)
  document.addEventListener("turbo:frame-render", scan)
  scan()
})()`
