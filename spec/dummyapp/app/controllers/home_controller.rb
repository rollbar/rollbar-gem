class HomeController < ApplicationController
  def index
    @users = User.all

    Rollbar.report_message("Test message from controller with no data", "debug")
    Rollbar.report_message("Test message from controller with extra data", "debug",
                             :foo => "bar", :num_users => @users.length)
  end

  def report_exception
    begin
      foo = bar
    rescue => e
      Rollbar.report_exception(e, rollbar_request_data, rollbar_person_data)
    end
  end

  def cause_exception
    foo = bar
  end

  def current_user
    User.find_by_encrypted_password(cookies[:session_id])
  end
  
  def custom_current_user
    user = User.new
    user.id = 123
    user.username = 'test'
    user.email = 'email@test.com'
    user
  end
end
