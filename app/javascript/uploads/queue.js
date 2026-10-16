const DATABASE = "scavenger-hunt-party"
const STORE = "queued_uploads"
const CHANGED = "upload-queue:changed"

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1)
    request.onupgradeneeded = () => {
      const store = request.result.createObjectStore(STORE, { keyPath: "id", autoIncrement: true })
      store.createIndex("teamId", "teamId")
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function transaction(mode, operate) {
  const database = await openDatabase()
  try {
    return await new Promise((resolve, reject) => {
      const store = database.transaction(STORE, mode).objectStore(STORE)
      const request = operate(store)
      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error)
    })
  } finally {
    database.close()
  }
}

function announce() {
  window.dispatchEvent(new CustomEvent(CHANGED))
}

export async function enqueue(entry) {
  const id = await transaction("readwrite", (store) => store.add({ ...entry, queuedAt: Date.now() }))
  announce()
  return id
}

export async function remove(id) {
  await transaction("readwrite", (store) => store.delete(id))
  announce()
}

export function entries(teamId) {
  if (teamId === undefined) {
    return transaction("readonly", (store) => store.getAll())
  }
  return transaction("readonly", (store) => store.index("teamId").getAll(teamId))
}

export function count(teamId) {
  if (teamId === undefined) {
    return transaction("readonly", (store) => store.count())
  }
  return transaction("readonly", (store) => store.index("teamId").count(teamId))
}

export function onChange(callback) {
  window.addEventListener(CHANGED, callback)
  return () => window.removeEventListener(CHANGED, callback)
}
