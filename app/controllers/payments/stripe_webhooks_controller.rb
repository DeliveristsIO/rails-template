# frozen_string_literal: true

# Where a payment actually becomes a payment.
#
# Stripe posts here from its own servers, so there is no session, no CSRF token
# and no locale to negotiate — the signature is the whole of the authentication,
# and an event that does not verify is discarded before anything reads it.
#
# Every handler is idempotent. Stripe retries a webhook it did not get a 2xx
# for, and redelivers events days later; the second delivery must be a no-op,
# not a second unlock.
class Payments::StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  # POST /webhooks/stripe
  def create
    event = Payments::StripeConfig.verify_event(payload: request.body.read,
                                                signature: request.headers["Stripe-Signature"])

    case event.type
    when "checkout.session.completed" then complete(event.data.object)
    when "customer.subscription.created", "customer.subscription.updated",
         "customer.subscription.deleted" then adopt(event.data.object)
    end

    head :ok
  rescue Stripe::SignatureVerificationError, JSON::ParserError => e
    Rails.logger.warn("stripe webhook rejected (#{e.class}: #{e.message})")
    head :bad_request
  end

  private
    # A completed subscription checkout says who the Stripe customer is and
    # nothing else worth trusting: the session carries no status and no period,
    # and a trial's `payment_status` reads `no_payment_required`. What the plan
    # actually becomes is decided by the subscription events below, which carry
    # the subscription itself. Recording the customer id here is what lets a
    # later event from the portal — where there is no session and no metadata
    # of ours — still find the account.
    #
    # TEMPLATE: a one-off `mode: "payment"` session lands here too. Branch on
    # `session.mode` before reading `client_reference_id`, and unlock on
    # `session.payment_status == "paid"` rather than on the session existing —
    # a completed session can still be an asynchronous method that never
    # settled.
    def complete(session)
      return unless session.mode == "subscription"

      user = user_for(session)
      return Rails.logger.warn("stripe subscription session for an unknown user: #{session.id}") if user.nil?

      user.update!(stripe_customer_id: Payments::StripeSubscription.customer_id_of(session))
    end

    # Every subscription event lands here: created, switched, renewed, lapsed,
    # cancelled. One method rather than one per event, because the answer is
    # always the same question — what does Stripe say this account is on right
    # now — and because Stripe redelivers, so the second delivery has to leave
    # the row exactly where the first one did.
    def adopt(subscription)
      user = user_for(subscription)
      return Rails.logger.warn("stripe subscription for an unknown user: #{subscription.id}") if user.nil?
      return if stale?(user, subscription)

      user.adopt_subscription!(
        id: subscription.id,
        status: subscription.status,
        plan: subscription.metadata&.[]("plan"),
        customer_id: Payments::StripeSubscription.customer_id_of(subscription),
        period_ends_at: period_end(subscription)
      )
    end

    # Stripe redelivers for days, and an account that cancelled and resubscribed
    # has two subscription ids. A late `deleted` for the old one would otherwise
    # drop a currently-paying account to the free ceilings. An event about a
    # subscription this account has already moved off is only ever news about
    # the past, so it is dropped rather than adopted.
    def stale?(user, subscription)
      held = user.stripe_subscription_id
      return false if held.blank? || held == subscription.id

      Rails.logger.info("stripe event for a superseded subscription #{subscription.id}, holding #{held}")
      true
    end

    def user_for(object) = Payments::StripeSubscription.owner_of(object)

    # Stripe moved the period onto the subscription's items; older payloads
    # still carry it at the top level, and a payload with neither is a
    # subscription whose renewal date this app simply does not know.
    def period_end(subscription)
      seconds = subscription.try(:current_period_end) ||
                subscription.try(:items)&.try(:data)&.first&.try(:current_period_end)

      Time.zone.at(seconds) if seconds.present?
    end
end
