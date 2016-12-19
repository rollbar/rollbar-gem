class Book < ActiveRecord::Base
  belongs_to :user

  after_validation :report_validation_errors_to_rollbar
end
