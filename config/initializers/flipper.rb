Rails.application.config.flipper.preload = false

Flipper.configure do |config|
  config.adapter do
    Flipper::Adapters::ActiveSupportCacheStore.new(
      Flipper::Adapters::ActiveRecord.new,
      Rails.cache
    )
  end
end
