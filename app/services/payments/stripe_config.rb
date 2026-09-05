# frozen_string_literal: true

# Where the Stripe credentials live, and the one place a webhook is believed.
#
# Named `StripeConfig` rather than `Stripe` on purpose: a `Payments::Stripe`
# would shadow the gem's own top-level `Stripe` for every constant lookup
# inside this namespace, and `Stripe::Checkout::Session` would quietly resolve
# to the wrong thing.
#
# Unconfigured is a supported state and the default one. Without a secret key
# nothing is offered for sale — no button, no route that half-works — the same
# way Turnstile renders nothing without its keys. An install with no Stripe
# account is a working free product rather than a broken paid one.
class Payments::StripeConfig
  DEFAULT_CURRENCY = "eur"

  # Stripe rejects a session whose success URL has no session id in it, and the
  # placeholder is substituted by Stripe rather than by us.
  SESSION_PLACEHOLDER = "{CHECKOUT_SESSION_ID}"

  # Stripe takes its own locale list. Ours are all on it, but a locale it does
  # not know would be rejected outright, so anything unexpected falls back to
  # letting Stripe decide from the browser.
  SUPPORTED_LOCALES = %w[ en de pl ].freeze

  class << self
    def configured? = secret_key.present?

    def secret_key = ENV["STRIPE_SECRET_KEY"].presence

    def webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].presence

    def currency = (ENV["STRIPE_CURRENCY"].presence || DEFAULT_CURRENCY).downcase

    # Live keys start `sk_live_`; everything else is a test key. Worth knowing
    # because a staging box pointed at live keys takes real money.
    def live? = secret_key.to_s.start_with?("sk_live_")

    def stripe_locale(locale) = SUPPORTED_LOCALES.include?(locale.to_s) ? locale.to_s : "auto"

    # Verifies the signature and returns the event. Raises rather than
    # returning nil: an unverified webhook is not a webhook, and the caller
    # must never be able to treat one as a payment by forgetting a nil check.
    def verify_event(payload:, signature:)
      raise Stripe::SignatureVerificationError.new("no webhook secret configured", signature) if webhook_secret.blank?

      Stripe::Webhook.construct_event(payload, signature.to_s, webhook_secret)
    end
  end
end
