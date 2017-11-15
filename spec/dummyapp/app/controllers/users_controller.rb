class UsersController < ApplicationController
  respond_to?(:before_action) ? (before_action :authenticate_user!) : (before_filter :authenticate_user!)

  def index
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
  end

  def start_session
    @user = User.find(params[:id])
    cookies[:session_id] = @user.encrypted_password
  end

end
