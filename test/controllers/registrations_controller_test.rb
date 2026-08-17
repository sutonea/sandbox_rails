require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "新規登録フォームを表示できる" do
    get signup_path

    assert_response :success
  end

  test "有効な属性で登録するとユーザーが作成されログイン状態になる" do
    assert_difference("User.count", 1) do
      post signup_path, params: {
        user: { username: "new_user", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_redirected_to root_path
    assert_equal User.find_by(username: "new_user").id, session[:user_id]
  end

  test "無効な属性では登録に失敗する" do
    assert_no_difference("User.count") do
      post signup_path, params: {
        user: { username: "ab", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_response :unprocessable_entity
  end
end
