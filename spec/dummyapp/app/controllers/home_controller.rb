class HomeController < ApplicationController
  def index
    @users = User.all

    Rollbar.debug("Test message from controller with no data")
    Rollbar.debug("Test message from controller with extra data",
                  :foo => "bar", :num_users => @users.length)
  end

  def report_exception
    begin
      foo = bar
    rescue => e
      Rollbar.error(e)
    end
  end

  def deprecated_report_exception
    begin
      foo = bar
    rescue => e
      Rollbar.report_exception(e)
    end
    render json: {}
  end


  def cause_exception
    foo = bar
  end

  def current_user
    @current_user ||= User.find_by_id(cookies[:session_id])
  end

  def custom_current_user
    user = User.new
    user.id = 123
    user.username = 'test'
    user.email = 'email@test.com'
    user
  end
end
