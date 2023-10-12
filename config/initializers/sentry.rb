Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.25

  config.enabled_environments = ["production"]
  config.excluded_exceptions += ["ActionController::RoutingError", "ActiveRecord::RecordNotFound", "Interrupt"]
end
