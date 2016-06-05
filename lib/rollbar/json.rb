module Rollbar
  module JSON
    extend self

    def dump(object)
      ::JSON.dump(object)
    end

    def load(string)
      ::JSON.load(string)
    end

    def oj!
      require 'rollbar/json/oj'
      extend Oj
    end

    # Makes it use Oj if it's available.
    def setup_backend
      require 'oj'
      oj!
    rescue LoadError
    end
  end
end

