class Webauthn::AuthenticationsController < ApplicationController
  def options
    get_options = WebAuthn::Credential.options_for_get(user_verification: "required")

    session[:webauthn_authentication_challenge] = get_options.challenge

    render json: get_options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_get(params)
    credential = WebauthnCredential.find_by(external_id: webauthn_credential.id)

    unless credential
      return render json: { status: "error", message: "登録されていない認証情報です" }, status: :unprocessable_entity
    end

    # sign_count の検証と更新の間で行ロックを取り、同一 assertion の同時多重送信による
    # リプレイ検知のすり抜けを防ぐ
    credential.with_lock do
      webauthn_credential.verify(
        session[:webauthn_authentication_challenge],
        public_key: credential.public_key,
        sign_count: credential.sign_count,
        user_verification: true
      )

      credential.update!(sign_count: webauthn_credential.sign_count)
    end

    reset_session
    session[:user_id] = credential.user_id

    render json: { status: "ok" }
  rescue WebAuthn::Error => e
    render json: { status: "error", message: e.message }, status: :unprocessable_entity
  ensure
    session.delete(:webauthn_authentication_challenge)
  end
end
