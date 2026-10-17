# frozen_string_literal: true

module SingleFlightVariant
  LOCK_WAIT = 15
  LOCK_POLL = 0.05
  SETTLED_AFTER = 1.minute

  def processed
    return self if processed? && image&.blob&.created_at&.before?(SETTLED_AFTER.ago)

    with_processing_lock { process unless processed? }
    self
  end

  private

  # Rails commits the variant record before it uploads the file, so a fresh
  # record is not proof the file exists. Waiting on the lock until whoever is
  # processing releases it covers both the resize and that upload.
  def with_processing_lock(&)
    ActiveStorage::VariantRecord.connection_pool.with_connection do |connection|
      connection.uncached { hold_processing_lock(connection, &) }
    end
  end

  def hold_processing_lock(connection)
    key = "hashtextextended(#{connection.quote("active_storage_variant:#{blob.id}:#{variation.digest}")}, 0)"
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + LOCK_WAIT
    locked = false
    until (locked = connection.select_value("SELECT pg_try_advisory_lock(#{key})")) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep LOCK_POLL
    end
    yield
  ensure
    connection.select_value("SELECT pg_advisory_unlock(#{key})") if locked
  end
end

ActiveSupport.on_load(:active_storage_blob) do
  ActiveStorage::VariantWithRecord.prepend(SingleFlightVariant)
end
