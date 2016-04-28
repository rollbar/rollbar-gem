class Post
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  attr_accessor :title

  validates_presence_of :title
  after_validation :report_validation_errors_to_rollbar
end
