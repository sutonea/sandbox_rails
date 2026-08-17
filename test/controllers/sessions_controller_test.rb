require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "ログインフォームを表示できる" do
    get login_path

    assert_response :success
  end

  test "正しいユーザー名とパスワードでログインできる" do
    post login_path, params: { username: users(:one).username, password: "password123" }

    assert_redirected_to root_path
    assert_equal users(:one).id, session[:user_id]
  end

  test "誤ったパスワードではログインできない" do
    post login_path, params: { username: users(:one).username, password: "wrong_password" }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "存在しないユーザー名ではログインできない" do
    post login_path, params: { username: "unknown_user", password: "password123" }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "ログアウトするとセッションが破棄される" do
    post login_path, params: { username: users(:one).username, password: "password123" }

    delete logout_path

    assert_redirected_to login_path
    assert_nil session[:user_id]
  end
end
