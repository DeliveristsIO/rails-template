require "test_helper"

# The one page that changes what an account may do. Its job is to say the same
# numbers the validations enforce, and to offer nothing at all when there is
# nothing configured to sell.
class SubscriptionsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:reader) }

  test "the plan page is for the account, not for the public" do
    delete sign_out_path

    get subscription_path

    assert_redirected_to sign_in_path(return_to: subscription_path)
  end

  test "it lists every tier with the ceilings the product enforces" do
    get subscription_path

    assert_response :success
    Plan.all.each { |plan| assert_select "body", /#{Regexp.escape(plan.name)}/ }
    assert_select "body", /#{Plan.find(Plan::BUSINESS).projects}/
  end

  test "it says which plan the account is on" do
    get subscription_path

    assert_select "body", /#{Regexp.escape(I18n.t("subscriptions.show.on_this_plan"))}/
  end

  # Unconfigured is a supported state and the current one. The page still
  # explains the tiers — that is information — but it must not offer a button
  # that goes nowhere.
  test "with no Stripe key nothing is on sale" do
    get subscription_path

    assert_select "body", /#{Regexp.escape(I18n.t("subscriptions.show.unavailable"))}/
    assert_select "form[action=?]", subscription_path, false
  end

  test "with a Stripe key each paid tier can be bought" do
    with_stripe { get subscription_path }

    assert_select "form[action=?]", subscription_path, count: Plan.paid.size
  end

  test "starting a checkout with no Stripe key is not a route at all" do
    post subscription_path, params: { plan: Plan::TEAM }

    assert_response :not_found
  end

  test "a plan nobody sells is refused before Stripe is asked" do
    with_stripe { post subscription_path, params: { plan: "enterprise" } }

    assert_redirected_to subscription_path
    assert_equal I18n.t("subscriptions.errors.unknown_plan"), flash[:alert]
  end

  # "Free" is not something to buy, and asking Stripe for a zero-amount
  # recurring price is how you find that out the expensive way.
  test "the free plan is not for sale" do
    with_stripe { post subscription_path, params: { plan: Plan::FREE } }

    assert_redirected_to subscription_path
    assert_equal I18n.t("subscriptions.errors.unknown_plan"), flash[:alert]
  end

  test "a chosen tier goes to Stripe and the browser follows it" do
    stub_checkout_session(id: "cs_test_sub", url: "https://checkout.stripe.com/c/pay/cs_test_sub")

    with_stripe { post subscription_path, params: { plan: Plan::TEAM } }

    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_sub"
  end

  test "a Stripe that cannot be reached charges nothing and says so" do
    stub_checkout_session_failure

    with_stripe { post subscription_path, params: { plan: Plan::TEAM } }

    assert_redirected_to subscription_path
    assert_equal I18n.t("subscriptions.errors.unavailable"), flash[:alert]
    assert_equal Plan::FREE, users(:reader).reload.current_plan.key
  end

  # The portal is where a customer changes or cancels a plan. Without a Stripe
  # customer there is nothing to open, which is a sentence rather than an error.
  test "the portal is not offered before there is a customer to open it for" do
    with_stripe { post portal_subscription_path }

    assert_redirected_to subscription_path
    assert_equal I18n.t("subscriptions.errors.no_customer"), flash[:alert]
  end

  test "the portal opens for an account Stripe already knows" do
    users(:reader).update!(stripe_customer_id: "cus_test_1")
    stub_request(:post, "https://api.stripe.com/v1/billing_portal/sessions")
      .to_return(status: 200, body: { id: "bps_1", url: "https://billing.stripe.com/p/session/test" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    with_stripe { post portal_subscription_path }

    assert_redirected_to "https://billing.stripe.com/p/session/test"
  end

  # Coming back from Stripe is the browser talking, and the browser is the one
  # party to this transaction the app does not control.
  test "coming back from checkout claims nothing the webhook has not confirmed" do
    get success_subscription_path

    assert_redirected_to subscription_path
    assert_equal I18n.t("subscriptions.confirming"), flash[:notice]
  end

  test "coming back after the webhook landed says the plan is live" do
    users(:reader).update!(plan: Plan::TEAM, subscription_status: "active")

    get success_subscription_path

    assert_equal I18n.t("subscriptions.confirmed"), flash[:notice]
  end
end
