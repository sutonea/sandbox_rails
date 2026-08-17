class User < ApplicationRecord
  has_secure_password

  has_many :webauthn_credentials, dependent: :destroy

  validates :username,
            presence: true,
            uniqueness: true,
            length: { minimum: 3, maximum: 32 },
            format: { with: /\A[a-zA-Z0-9_-]+\z/ }
end
