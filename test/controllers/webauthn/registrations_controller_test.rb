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

  test "有効な attestation でパスキーを登録できる" do
    login_as(users(:one))
    client = WebAuthn::FakeClient.new(FAKE_ORIGIN)

    post webauthn_registration_options_path
    challenge = JSON.parse(response.body)["challenge"]

    credential = client.create(challenge: challenge)

    assert_difference("WebauthnCredential.count", 1) do
      post webauthn_registration_path, params: credential, as: :json
    end

    assert_response :success
    assert_equal "ok", JSON.parse(response.body)["status"]
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
