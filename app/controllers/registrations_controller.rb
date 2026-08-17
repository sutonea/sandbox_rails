class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    user = User.new(registration_params)

    if user.save
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "登録しました"
    else
      @user = user
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:username, :password, :password_confirmation)
  end
end
