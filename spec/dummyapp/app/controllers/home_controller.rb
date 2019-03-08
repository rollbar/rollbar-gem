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
      Rollbar.error(e)
    end
    render :json => {}
  end

  def cause_exception
    foo = bar
  end

  def cause_exception_with_locals
    foo = false

    (0..2).each do |index|
      foo = Post

      build_hash_with_locals(foo, index)
    end
  end

  def build_hash_with_locals(foo, _index)
    foo.tap do |obj|
      password = '123456'
      hash = { :foo => obj, :bar => 'bar' }
      hash.invalid_method
    end
  end

  def test_rollbar_js
    render 'js/test', :layout => 'simple'
  end

  def file_upload
    this = will_crash
  end

  def set_session_data
    session[:some_value] = 'this-is-a-cool-value'

    render :json => {}
  end

  def use_session_data
    oh = this_is_crashing!
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

  def recursive_current_user
    Rollbar.error('Recurisve call to rollbar')
  end
end
