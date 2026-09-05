require "test_helper"

# The one defence here that a rotating address does not answer. Rate limits ask
# how much a caller has spent, which assumes the caller is hard to become again;
# a VPN, a proxy pool or a fresh private window makes that false. This asks
# whether there is a person behind the browser instead.
class TurnstileTest < ActiveSupport::TestCase
  ENDPOINT = Turnstile::ENDPOINT

  teardown { %w[ TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY ].each { |key| ENV.delete(key) } }

  def configured
    ENV["TURNSTILE_SITE_KEY"] = "site"
    ENV["TURNSTILE_SECRET_KEY"] = "secret"
  end

  # The current state, and a supported one: without keys the product behaves
  # exactly as it does today rather than refusing everybody.
  test "unconfigured admits everybody and asks Cloudflare nothing" do
    assert_not Turnstile.configured?
    assert Turnstile.human?(token: nil)

    assert_not_requested :post, ENDPOINT
  end

  test "half a key pair is not configured" do
    ENV["TURNSTILE_SITE_KEY"] = "site"

    assert_not Turnstile.configured?
  end

  test "a token Cloudflare accepts is a person" do
    configured
    stub_request(:post, ENDPOINT).to_return(status: 200, body: { success: true }.to_json,
                                            headers: { "Content-Type" => "application/json" })

    assert Turnstile.human?(token: "a-token", ip: "203.0.113.9")

    assert_requested(:post, ENDPOINT) { |req|
      body = Rack::Utils.parse_nested_query(req.body)
      body["secret"] == "secret" && body["response"] == "a-token" && body["remoteip"] == "203.0.113.9"
    }
  end

  test "a token Cloudflare rejects is not" do
    configured
    stub_request(:post, ENDPOINT).to_return(status: 200,
      body: { success: false, "error-codes" => [ "invalid-input-response" ] }.to_json,
      headers: { "Content-Type" => "application/json" })

    assert_not Turnstile.human?(token: "a-forged-token")
  end

  test "no token at all is refused without asking" do
    configured

    assert_not Turnstile.human?(token: "")

    assert_not_requested :post, ENDPOINT
  end

  # An abuse defence that takes a form down when Cloudflare has a bad
  # minute has done more damage than the abuse it was there to stop.
  test "an unreachable verifier admits the request rather than blocking it" do
    configured
    stub_request(:post, ENDPOINT).to_timeout

    assert Turnstile.human?(token: "a-token")
  end

  test "so does an error response" do
    configured
    stub_request(:post, ENDPOINT).to_return(status: 502)

    assert Turnstile.human?(token: "a-token")
  end

  test "and a body that is not JSON" do
    configured
    stub_request(:post, ENDPOINT).to_return(status: 200, body: "<html>maintenance</html>")

    assert Turnstile.human?(token: "a-token")
  end
end
