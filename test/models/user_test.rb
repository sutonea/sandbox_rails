require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**overrides)
    User.new(
      username: "new_user",
      password: "password123",
      password_confirmation: "password123",
      **overrides
    )
  end

  test "有効な属性であれば保存できる" do
    user = build_user

    assert user.valid?
  end

  test "username がなければ無効" do
    user = build_user(username: nil)

    assert_not user.valid?
  end

  test "username が既存のものと重複していれば無効" do
    user = build_user(username: users(:one).username)

    assert_not user.valid?
  end

  test "username が2文字以下なら無効" do
    user = build_user(username: "ab")

    assert_not user.valid?
  end

  test "username が33文字以上なら無効" do
    user = build_user(username: "a" * 33)

    assert_not user.valid?
  end

  test "username に英数字・アンダースコア・ハイフン以外を含むと無効" do
    user = build_user(username: "invalid name!")

    assert_not user.valid?
  end

  test "password と password_confirmation が一致しなければ無効" do
    user = build_user(password_confirmation: "different")

    assert_not user.valid?
  end

  test "authenticate は正しいパスワードで true 相当のオブジェクトを返す" do
    user = users(:one)

    assert user.authenticate("password123")
  end

  test "authenticate は誤ったパスワードで false を返す" do
    user = users(:one)

    assert_not user.authenticate("wrong_password")
  end

  test "作成時に webauthn_id が自動生成される" do
    user = build_user

    user.save!

    assert user.webauthn_id.present?
  end

  test "webauthn_id が既に設定されている場合は上書きしない" do
    user = build_user(webauthn_id: "existing-webauthn-id")

    user.save!

    assert_equal "existing-webauthn-id", user.webauthn_id
  end
end
