ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# Cleared *after* the environment loads, because dotenv puts .env into ENV
# during Rails boot and would undo a delete made before it. Without this a
# developer with working credentials runs the suite against live services —
# slowly, with real spend, and with the key printed in WebMock's failure
# output. Tests that want a configured service set a fake key themselves.
#
# TEMPLATE: add every credential this app reads at call time to both lists.
CREDENTIALS = %w[ STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET STRIPE_CURRENCY
                  TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY ].freeze
CREDENTIALS.each { |key| ENV.delete(key) }

require "rails/test_help"
require "mocha/minitest"
require "webmock/minitest"

# Every external service is stubbed. A test that reaches a real endpoint is
# both flaky and a good way to get a shared address rate-limited, so unstubbed
# requests fail loudly instead.
WebMock.disable_net_connect!(allow_localhost: true)

Dir[Rails.root.join("test/support/**/*.rb")].each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include StripeStubs

    # Credentials are read from the environment at call time, so a test that
    # sets one has to put the environment back or it leaks into the next
    # test's idea of what is configured.
    teardown { CREDENTIALS.each { |key| ENV.delete(key) } }
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationHelpers
end
