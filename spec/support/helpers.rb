module Helpers
  def local?
    ENV['LOCAL'] == '1'
  end
end
