class User < ActiveRecord::Base
  attr_accessible :username, :email, :password, :password_confirmation, :remember_me
end
