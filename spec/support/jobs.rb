# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each, :test_queue_adapter) do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end
end

# Transactional tests pin one connection that every thread shares, guarded by the
# connection's own lock, so GoodJob's "connection before mutex" ordering no longer
# excludes anyone: the test thread can hold the tracker mutex while it waits for that
# lock, which a request thread holds through a commit that enqueues a job. Taking the
# connection lock first restores a single lock order.
module GoodJobTrackerLockOrder
  def synchronize(with_connection: false, &block)
    GoodJob::Process.connection_pool.with_connection do |connection|
      connection.lock.synchronize { super(with_connection: false, &block) }
    end
  end
end

GoodJob::CapsuleTracker.prepend(GoodJobTrackerLockOrder)
