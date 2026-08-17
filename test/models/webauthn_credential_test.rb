require "test_helper"

class WebauthnCredentialTest < ActiveSupport::TestCase
  test "user がなければ無効" do
    credential = WebauthnCredential.new(external_id: "abc", public_key: "key")

    assert_not credential.valid?
  end

  test "有効な属性であれば保存できる" do
    credential = WebauthnCredential.new(
      user: users(:one),
      external_id: "new-credential-id",
      public_key: "public-key",
      sign_count: 0
    )

    assert credential.valid?
  end

  test "user を通じて紐づくユーザーを取得できる" do
    credential = webauthn_credentials(:one)

    assert_equal users(:one), credential.user
  end

  test "user が削除されると関連する credential も削除される" do
    user = users(:one)

    assert_difference("WebauthnCredential.count", -1) do
      user.destroy
    end
  end
end
