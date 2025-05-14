class HomeController < ApplicationController
  def index
    @users = User.all

    Rollbar.debug('Test message from controller with no data')
    Rollbar.debug('Test message from controller with extra data',
                  :foo => 'bar', :num_users => @users.length)
  end

  def report_exception
    _foo = bar
  rescue StandardError => e
    Rollbar.error(e)
  end

  def deprecated_report_exception
    begin
      _foo = bar
    rescue StandardError => e
      Rollbar.error(e)
    end
    render :json => {}
  end

  def handle_rails_error
    Rails.error.handle do
      raise 'Handle Rails error'
    end

    render :json => {}
  end

  def record_rails_error
    Rails.error.record do
      raise 'Record Rails error'
    end
  end

  def cause_exception
    raise NameError, 'Uncaught Rails error'
  end

  def cause_exception_with_locals
    foo = false

    enumerator_using_fibers if params[:test_fibers]

    (0..2).each do |index|
      foo = Post

      build_hash_with_locals(foo, index)
    end
  end

  def enumerator_using_fibers
    # Calling each without a block returns an Iterator.
    # Calling #next on the iterator causes execution on a fiber.
    [1, 2, 3].each.next
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

  def test_rollbar_js_with_nonce
    # Cause a secure_headers nonce to be added to script_src
    ::SecureHeaders.content_security_policy_script_nonce(request)

    render 'js/test', :layout => 'simple'
  end

  def file_upload
    _this = will_crash
  end

  def set_session_data
    session[:some_value] = 'this-is-a-cool-value'

    render :json => {}
  end

  def use_session_data
    _oh = this_is_crashing!
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
