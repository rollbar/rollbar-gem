class User < ActiveRecord::Base
  attr_accessible :username, :email, :password, :password_confirmation, :remember_me if Rails::VERSION::MAJOR < 4

  validates_presence_of :email
  after_validation :report_validation_errors_to_rollbar
end
