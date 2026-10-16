const DATABASE = "scavenger-hunt-party"
const STORE = "queued_uploads"
const CHANGED = "upload-queue:changed"

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 2)
    request.onupgradeneeded = () => {
      const database = request.result
      const store = database.objectStoreNames.contains(STORE)
        ? request.transaction.objectStore(STORE)
        : database.createObjectStore(STORE, { keyPath: "id", autoIncrement: true })
      if (!store.indexNames.contains("teamId")) store.createIndex("teamId", "teamId")
      if (!store.indexNames.contains("submissionId")) store.createIndex("submissionId", "submissionId")
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function transaction(mode, operate) {
  const database = await openDatabase()
  try {
    return await new Promise((resolve, reject) => {
      const tx = database.transaction(STORE, mode)
      let result
      const track = (request) => {
        request.onsuccess = () => { result = request.result }
        return request
      }
      operate(tx.objectStore(STORE), track)
      tx.oncomplete = () => resolve(result)
      tx.onerror = () => reject(tx.error)
      tx.onabort = () => reject(tx.error || new Error("The upload queue transaction was aborted"))
    })
  } finally {
    database.close()
  }
}

function announce() {
  window.dispatchEvent(new CustomEvent(CHANGED))
}

export async function enqueue(entry) {
  const id = await transaction("readwrite", (store, track) => {
    const previous = store.index("submissionId").getAllKeys(IDBKeyRange.only(entry.submissionId))
    previous.onsuccess = () => {
      previous.result.forEach((key) => store.delete(key))
      track(store.add({ ...entry, queuedAt: Date.now() }))
    }
  })
  announce()
  return id
}

export async function remove(id) {
  await transaction("readwrite", (store, track) => track(store.delete(id)))
  announce()
}

export function entries(teamId) {
  if (teamId === undefined) {
    return transaction("readonly", (store, track) => track(store.getAll()))
  }
  return transaction("readonly", (store, track) => track(store.index("teamId").getAll(teamId)))
}

export function count(teamId) {
  if (teamId === undefined) {
    return transaction("readonly", (store, track) => track(store.count()))
  }
  return transaction("readonly", (store, track) => track(store.index("teamId").count(teamId)))
}

export function onChange(callback) {
  window.addEventListener(CHANGED, callback)
  return () => window.removeEventListener(CHANGED, callback)
}
