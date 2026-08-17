import { Controller } from "@hotwired/stimulus"
import { get, supported } from "@github/webauthn-json"

export default class extends Controller {
  static targets = ["status"]

  async connect() {
    if (!supported()) {
      this.element.hidden = true
      return
    }

    if (await this.conditionalMediationAvailable()) {
      this.authenticate({ mediation: "conditional" })
    }
  }

  authenticateWithButton() {
    this.authenticate({})
  }

  async conditionalMediationAvailable() {
    return !!(
      window.PublicKeyCredential &&
      PublicKeyCredential.isConditionalMediationAvailable &&
      (await PublicKeyCredential.isConditionalMediationAvailable())
    )
  }

  async authenticate({ mediation }) {
    this.setStatus("パスキーで認証しています…")

    try {
      const optionsResponse = await fetch("/webauthn/authentication/options", {
        method: "POST",
        headers: this.jsonHeaders(),
      })

      if (!optionsResponse.ok) {
        throw new Error("オプションの取得に失敗しました")
      }

      const options = await optionsResponse.json()
      const getOptions = { publicKey: options }
      if (mediation) {
        getOptions.mediation = mediation
      }

      const credential = await get(getOptions)

      const authResponse = await fetch("/webauthn/authentication", {
        method: "POST",
        headers: this.jsonHeaders(),
        body: JSON.stringify(credential),
      })

      const result = await authResponse.json()

      if (authResponse.ok && result.status === "ok") {
        window.location.href = "/"
      } else {
        this.setStatus(`認証に失敗しました: ${result.message ?? ""}`)
      }
    } catch (error) {
      console.error(error)
      this.setStatus("パスキーでの認証はキャンセルされました")
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
