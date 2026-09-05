# frozen_string_literal: true

require "test_helper"

# A throttled submission used to answer text/plain, which Turbo will not render:
# the visitor pressed the button and the page sat there doing nothing. The
# response has to be an HTML page, in their language.
class ThrottlingTest < ActionDispatch::IntegrationTest
  setup do
    # Tests run against the null cache, where a counter can never increment, so
    # the throttle needs a store of its own to be exercised at all.
    @store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @store
  end

  test "a throttled submission answers a page Turbo can render" do
    exhaust_the_signup_limit

    post sign_up_path, params: { user: { email_address: "founder@example.com", password: "correct horse battery" } }

    assert_response :too_many_requests
    assert_match "text/html", response.media_type
    assert_match I18n.t("errors.throttled.title"), response.body
    assert response.headers["Retry-After"].to_i.positive?
    assert_nil User.find_by(email_address: "founder@example.com")
  end

  test "it answers in the locale the visitor was using" do
    exhaust_the_signup_limit

    post sign_up_path(locale: "pl"), params: { user: { email_address: "", password: "" } }

    assert_response :too_many_requests
    assert_match I18n.t("errors.throttled.title", locale: :pl), response.body
  end

  # A programmatic caller cannot read a styled page. It gets the header that
  # says when to come back and nothing to render.
  test "a throttled API caller is answered in JSON" do
    11.times { post "/api/anything" }

    post "/api/anything"

    assert_response :too_many_requests
    assert_equal "application/json", response.media_type
    assert_equal "rate_limited", response.parsed_body["error"]
    assert_operator response.parsed_body["retry_after"].to_i, :>, 0
  end

  # Per address as well as per IP, so that a distributed attempt on one known
  # account spends a different budget from a single host working through many.
  test "guessing at one account's password is throttled before the ip ceiling" do
    address = users(:reader).email_address

    10.times { post sign_in_path, params: { email_address: address, password: "wrong" } }

    post sign_in_path, params: { email_address: address, password: AuthenticationHelpers::PASSWORD }

    assert_response :too_many_requests
  end

  # Health checks come from the proxy on every interval; counting them would
  # throttle the container out of its own rotation.
  test "the health check is never throttled" do
    301.times { get rails_health_check_path }

    assert_response :success
  end

  private
    def exhaust_the_signup_limit
      11.times { post sign_up_path, params: { user: { email_address: "", password: "" } } }
    end
end
