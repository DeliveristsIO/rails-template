class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # A check deleted while its chain was in flight should not wedge the queue.
  discard_on ActiveJob::DeserializationError
end
