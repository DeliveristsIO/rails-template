# frozen_string_literal: true

# Error tracking. Without a DSN this is inert, which is how development and
# test stay quiet — but a public URL with no error reporting means a failure
# reaches a founder and nobody else.
return if ENV["SENTRY_DSN"].blank?

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = Rails.env
  config.release = ENV["GIT_SHA"].presence

  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.send_default_pii = false

  # A candidate name someone has not announced yet is the most sensitive thing
  # this app holds. It must never travel to an error tracker.
  config.before_send = lambda do |event, _hint|
    event.request&.data = nil
    event.request&.query_string = nil
    event
  end

  # Enough to see a regression in the pipeline without paying to trace every
  # health check.
  config.traces_sample_rate = 0.1
  config.excluded_exceptions += %w[ ActionController::RoutingError ]
end
