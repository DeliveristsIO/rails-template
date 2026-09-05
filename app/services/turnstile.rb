# frozen_string_literal: true

# Cloudflare Turnstile, the one defence here that survives a rotating address.
#
# Rate limits meter whoever is asking — by address, or by account once there is
# one. Both assume the asker is hard to become again. A VPN, a proxy pool or a
# fresh private window makes that assumption false, and no counter keyed on
# either can tell the difference. A challenge asks a different question: not
# "how much has this caller spent" but "is this a browser with a person behind
# it", and rotating an address does not answer it.
#
# Unconfigured is a supported state and the current one. Without keys this
# renders nothing and admits everybody, so a form works exactly as it does
# without it; the keys are what turn it on, and that is deliberately an
# environment change rather than a deploy.
class Turnstile
  # Cloudflare failing, as distinct from the visitor failing.
  Unreachable = Class.new(StandardError)

  ENDPOINT = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  WIDGET_JS = "https://challenges.cloudflare.com/turnstile/v0/api.js"
  FIELD = "cf-turnstile-response"

  OPEN_TIMEOUT = 5

  # Short on purpose. This sits in front of a form, and a slow answer from
  # Cloudflare must cost a moment rather than the submission.
  READ_TIMEOUT = 10

  class << self
    def configured?
      site_key.present? && secret_key.present?
    end

    def site_key = ENV["TURNSTILE_SITE_KEY"].presence

    def secret_key = ENV["TURNSTILE_SECRET_KEY"].presence

    # True when this request may proceed. Unconfigured admits everybody, and so
    # does an unreachable verifier: a challenge is an abuse defence, and an
    # abuse defence that takes the product down when Cloudflare has a bad
    # minute has done more damage than the abuse it was there to stop.
    def human?(token:, ip: nil)
      return true unless configured?
      return false if token.blank?

      verify(token, ip)
    rescue StandardError => e
      Rails.logger.warn("turnstile unreachable, admitting the request (#{e.class}: #{e.message})")
      true
    end

    private
      def verify(token, ip)
        uri = URI(ENDPOINT)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data({ secret: secret_key, response: token, remoteip: ip }.compact)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(request)
        end

        # A non-200 is Cloudflare failing, not the visitor failing.
        raise Unreachable, "turnstile returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        Rails.logger.info("turnstile refused a submission (#{Array(body["error-codes"]).join(", ")})") unless body["success"]

        body["success"] == true
      end
  end
end
