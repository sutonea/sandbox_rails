require "test_helper"
require "webauthn/fake_client"

class Webauthn::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  FAKE_ORIGIN = "http://localhost:3000"

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def register_passkey_for(user, client)
    login_as(user)

    post webauthn_registration_options_path
    challenge = JSON.parse(response.body)["challenge"]

    post webauthn_registration_path, params: client.create(challenge: challenge), as: :json

    delete logout_path
  end

  test "ログインしていなくてもオプションを取得できる" do
    post webauthn_authentication_options_path

    assert_response :success
    body = JSON.parse(response.body)
    assert body["challenge"].present?
  end

  test "登録済みのパスキーで認証しログイン状態になる" do
    user = users(:one)
    client = WebAuthn::FakeClient.new(FAKE_ORIGIN)
    register_passkey_for(user, client)

    post webauthn_authentication_options_path
    challenge = JSON.parse(response.body)["challenge"]

    assertion = client.get(challenge: challenge)

    post webauthn_authentication_path, params: assertion, as: :json

    assert_response :success
    assert_equal "ok", JSON.parse(response.body)["status"]
    assert_equal user.id, session[:user_id]
  end

  test "認証に成功すると sign_count が更新される" do
    user = users(:one)
    client = WebAuthn::FakeClient.new(FAKE_ORIGIN)
    register_passkey_for(user, client)
    credential = user.webauthn_credentials.order(:id).last

    post webauthn_authentication_options_path
    challenge = JSON.parse(response.body)["challenge"]
    assertion = client.get(challenge: challenge)

    post webauthn_authentication_path, params: assertion, as: :json

    assert_operator credential.reload.sign_count, :>, 0
  end

  test "登録されていない認証情報では認証に失敗する" do
    other_client = WebAuthn::FakeClient.new(FAKE_ORIGIN)

    post webauthn_authentication_options_path
    challenge = JSON.parse(response.body)["challenge"]

    other_client.create(challenge: challenge) # DB に紐づかない認証情報を作成

    assertion = other_client.get(challenge: challenge)

    post webauthn_authentication_path, params: assertion, as: :json

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "challenge が一致しない場合は認証に失敗する" do
    user = users(:one)
    client = WebAuthn::FakeClient.new(FAKE_ORIGIN)
    register_passkey_for(user, client)

    post webauthn_authentication_options_path

    assertion = client.get # 別の challenge で作成された assertion

    post webauthn_authentication_path, params: assertion, as: :json

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end
end
