require 'ostruct'
require 'delayed_job'
require 'delayed/backend/base'

# This code is taken from delayed_job/spec/delayed/backend/test.rb.
#
# It just works as a in memory job backend. Job#save is modified to create
# a new Delayed::Worker and call #work_off(1) so the job is processed inline.

module Delayed
  module Backend
    module Test
      def self.run
        worker.work_off(1)
      end

      def self.worker
        prepare_worker unless @worker

        @worker
      end

      def self.prepare_worker
        @worker = ::Delayed::Worker.new
      end

      class Job
        attr_accessor :id, :priority, :attempts, :handler, :last_error, :run_at,
                      :locked_at, :locked_by, :failed_at, :queue

        include Delayed::Backend::Base

        cattr_accessor :id
        self.id = 0

        def initialize(hash = {})
          self.attempts = 0
          self.priority = 0
          self.id = (self.class.id += 1)
          hash.each { |k, v| send("#{k}=", v) }
        end

        def self.all
          @jobs ||= []
        end

        def self.count
          all.size
        end

        def self.delete_all
          all.clear
        end

        def self.create(attrs = {})
          new(attrs).tap(&:save)
        end

        def self.create!(*args)
          create(*args)
        end

        def self.clear_locks!(worker_name)
          all.select { |j| j.locked_by == worker_name }.each do |j|
            j.locked_by = nil
            j.locked_at = nil
          end
        end

        # Find a few candidate jobs to run
        # (in case some immediately get locked by others).
        def self.find_available(worker_name, limit = 5,
                                max_run_time = Worker.max_run_time)
          jobs = all.select do |j|
            j.run_at <= db_time_now &&
              (j.locked_at.nil? ||
                j.locked_at < db_time_now - max_run_time ||
                j.locked_by == worker_name) &&
              !j.failed?
          end
          jobs.select! { |j| j.priority <= Worker.max_priority } if Worker.max_priority
          jobs.select! { |j| j.priority >= Worker.min_priority } if Worker.min_priority
          jobs.select! { |j| Worker.queues.include?(j.queue) } if Worker.queues.any?
          jobs.sort_by! { |j| [j.priority, j.run_at] }[0..limit - 1]
        end

        # Lock this job for this worker.
        # Returns true if we have the lock, false otherwise.
        def lock_exclusively!(_max_run_time, worker)
          now = self.class.db_time_now
          if locked_by != worker
            # We don't own this job so we will update the locked_by name and the locked_at
            self.locked_at = now
            self.locked_by = worker
          end

          true
        end

        def self.db_time_now
          Time.current
        end

        def update_attributes(attrs = {})
          attrs.each { |k, v| send(:"#{k}=", v) }
          save
        end

        def destroy
          self.class.all.delete(self)
        end

        def save
          self.run_at ||= Time.current

          self.class.all << self unless self.class.all.include?(self)

          ::Delayed::Backend::Test.run

          true
        end

        def save!
          save
        end

        def reload
          reset
          self
        end
      end
    end
  end
end
