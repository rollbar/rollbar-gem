module Rollbar
  module Scrubbers
    module_function

    def scrub_value(value)
      if Rollbar.configuration.randomize_scrub_length
        random_filtered_value
      else
        '*' * 6
      end
    end

    def random_filtered_value
      '*' * rand(3..7)
    end
  end
end
