require "test_helper"
require "webauthn/fake_client"

class Webauthn::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  FAKE_ORIGIN = "http://localhost:3000"

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  test "ログインしていなければオプション取得は require_login にリダイレクトされる" do
    post webauthn_registration_options_path

    assert_redirected_to login_path
  end

  test "ログイン済みならオプションを取得できる" do
    login_as(users(:one))

    post webauthn_registration_options_path

    assert_response :success
    body = JSON.parse(response.body)
    assert body["challenge"].present?
  end

  test "user.id には DB の主キーではなく base64url エンコードされた webauthn_id が使われる" do
    user = users(:one)
    login_as(user)

    post webauthn_registration_options_path

    body = JSON.parse(response.body)
    assert_equal user.webauthn_id, body["user"]["id"]
    assert_not_equal user.id.to_s, body["user"]["id"]
    assert_nothing_raised { WebAuthn.configuration.encoder.decode(body["user"]["id"]) }
  end

  test "有効な attestation でパスキーを登録できる" do
    login_as(users(:one))
    client = WebAuthn::FakeClient.new(FAKE_ORIGIN)

    post webauthn_registration_options_path
    challenge = JSON.parse(response.body)["challenge"]

    credential = client.create(challenge: challenge, user_verified: true)

    assert_difference("WebauthnCredential.count", 1) do
      post webauthn_registration_path, params: credential, as: :json
    end

    assert_response :success
    assert_equal "ok", JSON.parse(response.body)["status"]
  end

  test "ユーザー検証(PIN/生体認証)されていない attestation では登録に失敗する" do
    login_as(users(:one))
    client = WebAuthn::FakeClient.new(FAKE_ORIGIN)

    post webauthn_registration_options_path
    challenge = JSON.parse(response.body)["challenge"]

    credential = client.create(challenge: challenge, user_verified: false)

    assert_no_difference("WebauthnCredential.count") do
      post webauthn_registration_path, params: credential, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "challenge が一致しない場合は登録に失敗する" do
    login_as(users(:one))
    client = WebAuthn::FakeClient.new(FAKE_ORIGIN)

    post webauthn_registration_options_path

    credential = client.create # 別の challenge で作成された attestation

    assert_no_difference("WebauthnCredential.count") do
      post webauthn_registration_path, params: credential, as: :json
    end

    assert_response :unprocessable_entity
  end
end
