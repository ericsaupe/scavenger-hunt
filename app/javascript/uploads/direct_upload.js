import { DirectUpload } from "@rails/activestorage"

function directUpload(file, url) {
  return new Promise((resolve, reject) => {
    new DirectUpload(file, url).create((error, blob) => {
      if (error) {
        reject(new Error(error))
      } else {
        resolve(blob)
      }
    })
  })
}

export async function uploadWithRetries(file, url, { attempts = 3, retryDelay = 1000 } = {}) {
  for (let attempt = 1; ; attempt++) {
    try {
      return await directUpload(file, url)
    } catch (e) {
      if (attempt >= attempts) {
        throw e
      }
      await new Promise((resolve) => setTimeout(resolve, retryDelay * 2 ** (attempt - 1)))
    }
  }
}
