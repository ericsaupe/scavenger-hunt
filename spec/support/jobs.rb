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
