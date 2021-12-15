import { Controller } from "@hotwired/stimulus"
import Compress from "compress.js"

export default class extends Controller {
  static targets = [ "field", "form", "icon" ]
  static values = {
    submitting: { type: Boolean, default: false }
  }

  submitForm(event) {
    // Skip if we are already submitting
    if (this.submittingValue) {
      return
    }

    let formTarget = this.formTarget
    this.submittingValue = true
    this.iconTarget.innerHTML = '<ion-icon name="cloud-upload-outline" class="animate__animated animate__bounce animate__infinite"></ion-icon>'
    this.compressImage(event).then(() => {
      if (formTarget.requestSubmit){
        formTarget.requestSubmit()
      } else {
        formTarget.submit()
      }
      event.target.disabled = true
    }).catch((e) => { console.log(e) })
  }

  compressImage(event) {
    const fieldTarget = this.fieldTarget
    const fileListItems = this.fileListItems.bind(this)
    return new Promise(function(resolve, reject) {
      try {
        const compress = new Compress()
        const files = [...fieldTarget.files]
        if (!files.every((file) => file && file['type'].split('/')[0] === 'image')) {
          return resolve()
        }
        compress.compress(files, {}).then((results) => {
          event.stopImmediatePropagation()
          const img = results[0]
          const base64str = img.data
          const imgExt = img.ext
          const file = new File([Compress.convertBase64ToFile(base64str, imgExt)], img.name)
          fieldTarget.files = fileListItems([file])
          resolve()
        })
      } catch (e) {
        reject(e)
      }
    })
  }

  fileListItems(files) {
    var b = new DataTransfer()
    for (var i = 0, len = files.length; i<len; i++) b.items.add(files[i])
    return b.files
  }
}
