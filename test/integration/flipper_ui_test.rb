require "test_helper"

# The flag UI can switch parts of the product off for every visitor, so it is
# not something to leave open on a public host.
class FlipperUiTest < ActionDispatch::IntegrationTest
  teardown { %w[ FLIPPER_USERNAME FLIPPER_PASSWORD ].each { |key| ENV.delete(key) } }

  test "the flag UI is not reachable without credentials" do
    ENV["FLIPPER_USERNAME"] = "admin"
    ENV["FLIPPER_PASSWORD"] = "secret"

    get "/flipper"

    assert_response :unauthorized, "a browser needs a challenge, not a 404"
  end

  test "the flag UI is not reachable when no credentials are configured at all" do
    get "/flipper/features", headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }

    assert_response :unauthorized, "an unset password must not become an empty one that matches"
  end

  test "correct credentials reach it" do
    ENV["FLIPPER_USERNAME"] = "admin"
    ENV["FLIPPER_PASSWORD"] = "secret"

    # Flipper redirects /flipper to its features page; the integration client
    # does not resend the header on a redirect, so ask for the target directly.
    get "/flipper/features", headers: { "HTTP_AUTHORIZATION" => credentials("admin", "secret") }

    assert_response :success
  end

  test "a wrong password is refused even when the username is right" do
    ENV["FLIPPER_USERNAME"] = "admin"
    ENV["FLIPPER_PASSWORD"] = "secret"

    get "/flipper/features", headers: { "HTTP_AUTHORIZATION" => credentials("admin", "wrong") }

    assert_response :unauthorized
  end

  private
    def credentials(user, password)
      ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
    end
end
