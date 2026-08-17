import { Controller } from "@hotwired/stimulus"
import { create, supported } from "@github/webauthn-json"

export default class extends Controller {
  static targets = ["status"]

  connect() {
    if (!supported()) {
      this.element.hidden = true
    }
  }

  async register() {
    this.setStatus("パスキーを登録しています…")

    try {
      const optionsResponse = await fetch("/webauthn/registration/options", {
        method: "POST",
        headers: this.jsonHeaders(),
      })

      if (!optionsResponse.ok) {
        throw new Error("オプションの取得に失敗しました")
      }

      const options = await optionsResponse.json()
      const credential = await create({ publicKey: options })

      const createResponse = await fetch("/webauthn/registration", {
        method: "POST",
        headers: this.jsonHeaders(),
        body: JSON.stringify(credential),
      })

      const result = await createResponse.json()

      if (createResponse.ok && result.status === "ok") {
        this.setStatus("パスキーを登録しました")
      } else {
        this.setStatus(`登録に失敗しました: ${result.message ?? ""}`)
      }
    } catch (error) {
      console.error(error)
      this.setStatus("パスキーの登録に失敗しました")
    }
  }

  setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }

  jsonHeaders() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
    }
  }
}
