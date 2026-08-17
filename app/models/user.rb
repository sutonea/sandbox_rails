class User < ApplicationRecord
  has_secure_password

  has_many :webauthn_credentials, dependent: :destroy

  before_create { self.webauthn_id ||= WebAuthn.generate_user_id }

  validates :username,
            presence: true,
            uniqueness: true,
            length: { minimum: 3, maximum: 32 },
            format: { with: /\A[a-zA-Z0-9_-]+\z/ }
end
