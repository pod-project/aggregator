# frozen_string_literal: true

# :nodoc:
class ApplicationJob < ActiveJob::Base
  include ActiveJob::Status

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def self.with_job_tracking
    after_enqueue :find_or_initialize_job_tracker
    before_perform :find_or_initialize_job_tracker
    after_perform :cleanup_job_tracker
  end

  private

  def find_or_initialize_job_tracker
    JobTracker.find_or_create_by(job_id:) do |tracker|
      tracker.job_class = self.class.name
      tracker.provider_job_id = provider_job_id
      update_job_tracker_properties(tracker)
    end
  end

  def update_job_tracker_properties(tracker)
    tracker.resource = arguments.first
  end

  def cleanup_job_tracker
    JobTracker.where(job_id:).delete_all
  end
end
