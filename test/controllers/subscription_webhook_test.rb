require "test_helper"

# The webhook is where a payment actually becomes a payment. Every valid event
# here is signed with Stripe's own scheme and verified by Stripe's own code,
# because the signature is the whole of the authentication.
class SubscriptionWebhookTest < ActionDispatch::IntegrationTest
  setup { @user = users(:reader) }

  test "a subscription that starts puts the account on the plan it paid for" do
    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::TEAM))

    assert_response :success
    @user.reload
    assert_equal Plan::TEAM, @user.current_plan.key
    assert_equal "sub_test_1", @user.stripe_subscription_id
    assert_equal "cus_test_1", @user.stripe_customer_id
    assert @user.plan_period_ends_at.present?
  end

  # The whole point of the tier: the number the product enforces moves with it.
  test "the plan raises the ceilings the product actually refuses on" do
    assert_equal Plan.free.projects, @user.current_plan.projects

    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::BUSINESS))

    assert_equal Plan.find(Plan::BUSINESS).projects, @user.reload.current_plan.projects
  end

  test "a switched plan is adopted from the same event type as the first one" do
    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::STARTER))
    post_subscription_event("customer.subscription.updated", subscription_payload(@user, plan: Plan::BUSINESS))

    assert_equal Plan::BUSINESS, @user.reload.current_plan.key
  end

  # Stripe redelivers, days later and out of order. The second delivery has to
  # leave the row where the first one did.
  test "the same event delivered twice changes nothing the second time" do
    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::TEAM))
    first = @user.reload.attributes.slice("plan", "subscription_status", "stripe_subscription_id")

    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::TEAM))

    assert_equal first, @user.reload.attributes.slice("plan", "subscription_status", "stripe_subscription_id")
  end

  test "a cancelled subscription drops the account to the free ceilings" do
    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::BUSINESS))

    post_subscription_event("customer.subscription.deleted",
                            subscription_payload(@user, plan: Plan::BUSINESS, status: "canceled"))

    @user.reload
    assert_equal Plan::FREE, @user.current_plan.key
    assert_equal Plan.free.projects, @user.current_plan.projects
  end

  # An account that cancelled and resubscribed has two subscription ids, and
  # Stripe redelivers for days. A late `deleted` for the one it moved off would
  # otherwise cancel a subscription somebody is currently paying for.
  test "a late event about a superseded subscription cannot cancel the live one" do
    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::TEAM))

    post_subscription_event("customer.subscription.deleted",
                            subscription_payload(@user, plan: Plan::STARTER, status: "canceled", id: "sub_old_0"))

    @user.reload
    assert_equal Plan::TEAM, @user.current_plan.key
    assert_equal "sub_test_1", @user.stripe_subscription_id
  end

  # A card that stopped working is not a reason to keep charging nothing and
  # granting everything.
  test "a payment that fails drops the ceilings without losing the subscription" do
    post_subscription_event("customer.subscription.created", subscription_payload(@user, plan: Plan::TEAM))

    post_subscription_event("customer.subscription.updated",
                            subscription_payload(@user, plan: Plan::TEAM, status: "past_due"))

    @user.reload
    assert_equal Plan::FREE, @user.current_plan.key
    # The column too, not only what `current_plan` computes from it: this is
    # the field somebody reads when the customer writes in asking what they
    # are on, and it must not say Team while the ceilings say free.
    assert_equal Plan::FREE, @user.plan
    assert_equal "past_due", @user.subscription_status
    assert_equal "sub_test_1", @user.stripe_subscription_id, "the subscription is still there to be fixed"
  end

  # The completed session says who the Stripe customer is and nothing else
  # worth trusting — no status, no period, and `no_payment_required` on a
  # trial. Recording the customer id is what lets a later event from the
  # portal, which carries no metadata of ours, still find the account.
  test "a completed checkout records the customer and decides no plan" do
    payload, signature = stripe_event(type: "checkout.session.completed",
                                      session: subscription_session_payload(@user))
    with_stripe do
      post stripe_webhook_path, params: payload,
           headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => signature }
    end

    assert_response :success
    @user.reload
    assert_equal "cus_test_1", @user.stripe_customer_id
    assert_equal Plan::FREE, @user.current_plan.key, "the plan waits for the subscription event"
  end

  # A subscription and a one-off payment carry different things in
  # `client_reference_id`, so the mode has to be read before the field is.
  test "a session in a mode this app does not sell is ignored" do
    payload, signature = stripe_event(type: "checkout.session.completed",
                                      session: subscription_session_payload(@user).merge(mode: "payment"))
    with_stripe do
      post stripe_webhook_path, params: payload,
           headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => signature }
    end

    assert_response :success
    assert_nil @user.reload.stripe_customer_id
  end

  # No user, no adoption — and above all no exception, because a webhook that
  # 500s is a webhook Stripe retries forever.
  test "an event for an account this app has never seen is dropped quietly" do
    payload = { id: "sub_other", status: "active", customer: "cus_unknown",
                metadata: { user_id: "0", plan: Plan::BUSINESS } }

    post_subscription_event("customer.subscription.updated", payload)

    assert_response :success
  end

  test "an unsigned subscription event changes nothing" do
    body, = stripe_event(type: "customer.subscription.created",
                         session: subscription_payload(@user), object: "subscription")

    with_stripe { post stripe_webhook_path, params: body, headers: { "CONTENT_TYPE" => "application/json" } }

    assert_response :bad_request
    assert_equal Plan::FREE, @user.reload.current_plan.key
  end

  # Without a secret nothing can be verified, so nothing may be believed.
  test "with no webhook secret configured every event is refused" do
    body, signature = stripe_event(type: "customer.subscription.created", session: subscription_payload(@user),
                                   object: "subscription")

    post stripe_webhook_path, params: body,
         headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => signature }

    assert_response :bad_request
    assert_equal Plan::FREE, @user.reload.current_plan.key
  end
end
