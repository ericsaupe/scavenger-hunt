Flipper.configure do |config|
  config.adapter do
    Flipper::Adapters::ActiveSupportCacheStore.new(
      Flipper::Adapters::Memory.new,
      Rails.cache
    )
  end
end
