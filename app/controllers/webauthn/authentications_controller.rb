class Webauthn::AuthenticationsController < ApplicationController
  def options
    get_options = WebAuthn::Credential.options_for_get

    session[:webauthn_authentication_challenge] = get_options.challenge

    render json: get_options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_get(params)
    credential = WebauthnCredential.find_by(external_id: webauthn_credential.id)

    unless credential
      return render json: { status: "error", message: "登録されていない認証情報です" }, status: :unprocessable_entity
    end

    webauthn_credential.verify(
      session[:webauthn_authentication_challenge],
      public_key: credential.public_key,
      sign_count: credential.sign_count
    )

    credential.update!(sign_count: webauthn_credential.sign_count)

    reset_session
    session[:user_id] = credential.user_id

    render json: { status: "ok" }
  rescue WebAuthn::Error => e
    render json: { status: "error", message: e.message }, status: :unprocessable_entity
  ensure
    session.delete(:webauthn_authentication_challenge)
  end
end
