require "test_helper"

# Where the challenge sits: in front of the verbs a rotating address makes
# free. Signing up is the one this skeleton ships with — add the product's own
# expensive verb to the same list rather than inventing a second mechanism.
class ChallengeTest < ActionDispatch::IntegrationTest
  ACCOUNT = { email_address: "person@example.com", password: "correct horse battery" }.freeze

  setup do
    ENV["TURNSTILE_SITE_KEY"] = "site"
    ENV["TURNSTILE_SECRET_KEY"] = "secret"
  end

  def stub_turnstile(success)
    stub_request(:post, Turnstile::ENDPOINT).to_return(
      status: 200, body: { success: success }.to_json, headers: { "Content-Type" => "application/json" }
    )
  end

  test "a refused signup creates no account" do
    stub_turnstile false

    assert_no_difference -> { User.count } do
      post sign_up_path, params: { user: ACCOUNT, Turnstile::FIELD => "forged" }
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.challenge_failed")
  end

  test "a passed signup creates one and signs it in" do
    stub_turnstile true

    assert_difference -> { User.count }, 1 do
      post sign_up_path, params: { user: ACCOUNT, Turnstile::FIELD => "a-token" }
    end

    assert_redirected_to root_path
    assert_equal 1, Session.where(user: User.find_by(email_address: ACCOUNT[:email_address])).count
  end

  # A refused form has to come back with what was typed still in it.
  test "a refused signup keeps the address the visitor gave" do
    stub_turnstile false

    post sign_up_path, params: { user: ACCOUNT, Turnstile::FIELD => "forged" }

    assert_select "input[name='user[email_address]'][value=?]", ACCOUNT[:email_address]
  end

  test "the widget is on the form once it is configured" do
    get sign_up_path

    assert_select "div.cf-turnstile[data-sitekey=?]", "site"
  end

  # Cloudflare having a bad minute must not take the product down with it. An
  # abuse defence that refuses everybody has done more damage than the abuse.
  test "an unreachable verifier admits the request" do
    stub_request(:post, Turnstile::ENDPOINT).to_timeout

    assert_difference -> { User.count }, 1 do
      post sign_up_path, params: { user: ACCOUNT, Turnstile::FIELD => "a-token" }
    end
  end

  # The state this ships in. Nothing renders, nothing is asked, nothing changes.
  test "unconfigured, the form carries no widget and submits as it always did" do
    %w[ TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY ].each { |key| ENV.delete(key) }

    get sign_up_path
    assert_select "div.cf-turnstile", false

    assert_difference -> { User.count }, 1 do
      post sign_up_path, params: { user: ACCOUNT }
    end
  end
end
