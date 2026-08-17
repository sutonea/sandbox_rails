require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "ログインしていなければログイン画面にリダイレクトされる" do
    get root_path

    assert_redirected_to login_path
  end

  test "ログインしていればトップページを表示できる" do
    post login_path, params: { username: users(:one).username, password: "password123" }

    get root_path

    assert_response :success
  end
end
