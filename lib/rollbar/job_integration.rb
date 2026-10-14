module Rollbar
  # Tracks whether the current thread is running a job under one of Rollbar's
  # job integrations (Sidekiq, delayed_job). The scope inside such a job
  # belongs to it rather than being left over from a request, so
  # Rollbar::ActiveJob keeps it instead of resetting it.
  module JobIntegration
    KEY = :_rollbar_within_job_integration

    def self.within
      previous = Thread.current[KEY]
      Thread.current[KEY] = true

      yield
    ensure
      Thread.current[KEY] = previous
    end

    def self.within?
      Thread.current[KEY] == true
    end
  end
end
