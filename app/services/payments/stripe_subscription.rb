# frozen_string_literal: true

# Stripe Checkout for a plan, and the Billing Portal for everything after it.
#
# One flow up and one flow sideways. Starting a subscription is a checkout
# session; changing, pausing, cancelling one, or fixing a card that stopped
# working, is Stripe's own portal — which is already localised, already handles
# proration and dunning, and is already the page a customer's bank statement
# points at. Rebuilding those screens here would be three controllers whose
# only job is to be a worse version of a page Stripe maintains.
#
# Prices are built inline from `price_data` rather than looked up from price
# objects created in the dashboard: a handful of tiers, one currency, one
# interval, and a price that changes as a deploy setting rather than as a
# dashboard click nothing in this repository records. The cost of that choice
# is that a price id cannot identify a plan afterwards, so the plan key travels
# in the subscription's own metadata and the webhook reads it back from there.
#
# TEMPLATE: swap to Stripe price ids once there are more tiers, more currencies
# or an annual interval — inline data stops paying for itself at about six
# combinations.
class Payments::StripeSubscription
  class << self
    delegate :configured?, :secret_key, :webhook_secret, :currency, :live?, :stripe_locale,
             to: Payments::StripeConfig

    # Which plans are actually on sale. Without a key there is nothing to sell:
    # the page says so rather than offering a button that fails.
    def offered = configured? ? Plan.paid : []

    def create_session(user:, plan:, success_url:, cancel_url:, locale: I18n.locale)
      Stripe::Checkout::Session.create(
        {
          mode: "subscription",
          # Prefixed rather than bare. One-off payment sessions read this same
          # field, so an integer here would be ambiguous the day one is added.
          client_reference_id: reference_for(user),
          customer: user.stripe_customer_id.presence,
          customer_email: (user.email_address if user.stripe_customer_id.blank?),
          success_url:, cancel_url:,
          locale: stripe_locale(locale),
          line_items: [ {
            quantity: 1,
            price_data: {
              currency: currency,
              unit_amount: plan.price_cents,
              recurring: { interval: "month" },
              product_data: { name: I18n.t("plans.#{plan.key}.name", locale:),
                              description: I18n.t("plans.#{plan.key}.summary", locale:) }
            }
          } ],
          # The plan lives on the subscription rather than only on the session,
          # because the session is gone by the time a renewal or a downgrade
          # arrives and the subscription is what those events carry.
          subscription_data: { metadata: { plan: plan.key, user_id: user.id.to_s } },
          metadata: { plan: plan.key, user_id: user.id.to_s }
        },
        { api_key: secret_key }
      )
    end

    def portal_session(user:, return_url:)
      Stripe::BillingPortal::Session.create(
        { customer: user.stripe_customer_id, return_url: },
        { api_key: secret_key }
      )
    end

    def retrieve_subscription(id)
      Stripe::Subscription.retrieve(id, { api_key: secret_key })
    end

    def reference_for(user) = "user-#{user.id}"

    # The user a session or subscription belongs to. The metadata first,
    # because it is what this app put there; the customer id second, because it
    # is what survives a subscription created any other way — from the portal,
    # or by hand in the dashboard.
    def owner_of(object)
      metadata = object.respond_to?(:metadata) ? object.metadata : nil
      by_id = User.find_by(id: metadata&.[]("user_id"))
      by_id || User.find_by(stripe_customer_id: customer_id_of(object))
    end

    def customer_id_of(object)
      customer = object.try(:customer)
      customer.respond_to?(:id) ? customer.id : customer
    end
  end
end
