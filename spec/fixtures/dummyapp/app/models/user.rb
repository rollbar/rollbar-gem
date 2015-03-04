class User < ActiveRecord::Base

  if Rails::VERSION::MAJOR < 4
    attr_accessible :username, :email, :password, :password_confirmation, :remember_me
  end

end
