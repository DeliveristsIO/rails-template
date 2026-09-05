# frozen_string_literal: true

# The plan this account is on, and the one page that changes it.
#
# Two actions that talk to Stripe and one that reads. Upgrading is a checkout
# session; everything afterwards — switching tier, cancelling, resuming, a card
# that stopped working — is Stripe's own Billing Portal, which is localised,
# handles proration and dunning, and is the page the customer's statement
# already points at. Writing our own would be three more controllers competing
# with a page Stripe maintains.
#
# Nothing here decides what an account is allowed to do. The webhook does that,
# because the browser coming back from a redirect is the one party to this
# transaction the app does not control.
class SubscriptionsController < ApplicationController
  require_authentication

  before_action :discourage_indexing
  before_action :require_configured_payments, only: %i[ create portal ]

  # GET /subscription
  def show
    @plan = Current.user.current_plan
    @offered = Payments::StripeSubscription.offered
  end

  # POST /subscription
  def create
    plan = Plan.find(params[:plan])

    if plan.nil? || plan.free?
      return redirect_to subscription_path, alert: t("subscriptions.errors.unknown_plan")
    end

    session = Payments::StripeSubscription.create_session(
      user: Current.user, plan:,
      success_url: success_subscription_url, cancel_url: subscription_url
    )

    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("stripe subscription checkout failed for user #{Current.user.id} (#{e.class}: #{e.message})")
    redirect_to subscription_path, alert: t("subscriptions.errors.unavailable")
  end

  # POST /subscription/portal
  def portal
    if Current.user.stripe_customer_id.blank?
      return redirect_to subscription_path, alert: t("subscriptions.errors.no_customer")
    end

    session = Payments::StripeSubscription.portal_session(user: Current.user, return_url: subscription_url)
    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("stripe portal failed for user #{Current.user.id} (#{e.class}: #{e.message})")
    redirect_to subscription_path, alert: t("subscriptions.errors.unavailable")
  end

  # GET /subscription/success
  #
  # Says "we are confirming this", not "you are on the new plan" — the same
  # care the report's checkout takes. Stripe's webhook usually lands before the
  # browser does, and usually is not always.
  def success
    notice = Current.user.subscription_live? ? t("subscriptions.confirmed") : t("subscriptions.confirming")
    redirect_to subscription_path, notice:
  end

  private
    def require_configured_payments
      head :not_found unless Payments::StripeSubscription.configured?
    end
end
