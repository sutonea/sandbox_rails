class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create
  rate_limit to: 10, within: 3.minutes, by: -> { params[:username] }, only: :create

  def new
  end

  def create
    user = User.find_by(username: params[:username])

    if user&.authenticate(params[:password])
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "ログインしました"
    else
      flash.now[:alert] = "ユーザー名またはパスワードが違います"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "ログアウトしました"
  end
end
