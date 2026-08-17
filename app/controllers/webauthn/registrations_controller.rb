class Webauthn::RegistrationsController < ApplicationController
  before_action :require_login

  def options
    create_options = WebAuthn::Credential.options_for_create(
      user: { id: current_user.webauthn_id, name: current_user.username },
      exclude: current_user.webauthn_credentials.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "required" }
    )

    session[:webauthn_registration_challenge] = create_options.challenge

    render json: create_options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_create(params)
    webauthn_credential.verify(session[:webauthn_registration_challenge], user_verification: true)

    current_user.webauthn_credentials.create!(
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count,
      nickname: params[:nickname]
    )

    render json: { status: "ok" }
  rescue WebAuthn::Error => e
    render json: { status: "error", message: e.message }, status: :unprocessable_entity
  ensure
    session.delete(:webauthn_registration_challenge)
  end
end
