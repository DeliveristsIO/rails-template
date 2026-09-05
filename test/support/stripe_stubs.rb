# frozen_string_literal: true

# Stripe is never reached. Every test here runs against stubbed HTTP and a
# webhook signed with the same scheme Stripe signs with, because the one thing
# that must not be stubbed is the signature check itself.
module StripeStubs
  SESSION_URL = "https://checkout.stripe.com/c/pay/cs_test_123"
  SECRET = "whsec_test_secret"

  def with_stripe(secret_key: "sk_test_123", webhook_secret: SECRET)
    previous = { "STRIPE_SECRET_KEY" => ENV["STRIPE_SECRET_KEY"],
                 "STRIPE_WEBHOOK_SECRET" => ENV["STRIPE_WEBHOOK_SECRET"] }
    ENV["STRIPE_SECRET_KEY"] = secret_key
    ENV["STRIPE_WEBHOOK_SECRET"] = webhook_secret
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def stub_checkout_session(id: "cs_test_123", url: SESSION_URL)
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(status: 200, body: { id:, object: "checkout.session", url: }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_checkout_session_failure(status: 402)
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(status:, body: { error: { message: "card declined", type: "card_error" } }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  # The event body Stripe posts, signed the way Stripe signs it. Built rather
  # than fixture-loaded so a test can change one field — a status, say — and
  # still be posting something that verifies.
  def stripe_event(type:, session:, secret: SECRET, timestamp: Time.now.to_i, object: "checkout.session")
    payload = { id: "evt_test", object: "event", type:,
                data: { object: { object: }.merge(session) } }.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")

    [ payload, "t=#{timestamp},v1=#{signature}" ]
  end

  def subscription_session_payload(user, plan: Plan::TEAM, **overrides)
    { id: "cs_test_sub", mode: "subscription",
      client_reference_id: Payments::StripeSubscription.reference_for(user),
      customer: "cus_test_1", subscription: "sub_test_1",
      payment_status: "no_payment_required",
      metadata: { user_id: user.id.to_s, plan: } }.merge(overrides)
  end

  def subscription_payload(user, plan: Plan::TEAM, status: "active", **overrides)
    { id: "sub_test_1", status:, customer: "cus_test_1",
      metadata: { user_id: user.id.to_s, plan: },
      items: { object: "list",
               data: [ { id: "si_test_1", current_period_end: 30.days.from_now.to_i } ] } }.merge(overrides)
  end

  def post_subscription_event(type, payload)
    body, signature = stripe_event(type:, session: payload, object: "subscription")
    with_stripe do
      post stripe_webhook_path, params: body,
           headers: { "CONTENT_TYPE" => "application/json", "Stripe-Signature" => signature }
    end
  end
end
