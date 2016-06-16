module Rollbar
  module Scrubbers
    extend self

    def scrub_value(value)
      if Rollbar.configuration.randomize_scrub_length
        random_filtered_value
      else
        '*' * (value.length rescue 8)
      end
    end

    def random_filtered_value
      '*' * (rand(5) + 3)
    end
  end
end
