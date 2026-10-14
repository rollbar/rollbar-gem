module Rollbar
  # Tracks whether the current thread is running a job whose scope one of
  # Rollbar's job integrations set up (Sidekiq, or delayed_job with
  # dj_use_scoped_block). That scope belongs to the job rather than being left
  # over from a request, so Rollbar::ActiveJob keeps it instead of resetting it.
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
