WebAuthn.configure do |config|
  config.allowed_origins =
    if Rails.env.production?
      ENV.fetch("WEBAUTHN_ALLOWED_ORIGINS").split(",")
    else
      [ "http://localhost:3000" ]
    end

  config.rp_name = "Sandbox Rails"
end
