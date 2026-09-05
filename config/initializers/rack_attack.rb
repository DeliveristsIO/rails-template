# frozen_string_literal: true

# Anything on a public URL that costs real work invites scripted abuse, and a
# limit that only counts requests is not the same as a limit that counts what
# they spend. The rules here are deliberately generous for a person and useless
# for a loop.
#
# TEMPLATE: the sign-in and sign-up rules below are the ones every app wants
# unchanged. The rest is the shape rather than the numbers — add one throttle
# per expensive verb, and read its ceiling off the plan the way
# "expensive writes by user" does.
class Rack::Attack
  # Where the memoised caller id lives for the life of one request.
  USER_ID_KEY = "skeleton.rack_attack.user_id"
  PLAN_KEY = "skeleton.rack_attack.plan"

  # Rack::Attack sits below ActionDispatch::Cookies in the stack, so the signed
  # session cookie is readable here — which is what lets a limit follow the
  # person rather than the address.
  #
  # Memoised in the request env because several rules ask the same question. A
  # cookie that is missing, forged or points at a session since signed out
  # reads as anonymous — never as a raised limit.
  def self.current_user_id(request)
    env = request.env
    return env[USER_ID_KEY] if env.key?(USER_ID_KEY)

    env[USER_ID_KEY] = resolve_user_id(request)
  end

  def self.resolve_user_id(request)
    session_id = ActionDispatch::Request.new(request.env).cookie_jar.signed[Authentication::SESSION_COOKIE]
    Session.where(id: session_id).pick(:user_id) if session_id.present?
  rescue StandardError => e
    # An unreadable cookie is not a reason to refuse the request, and it must
    # not be a reason to grant a bigger budget either.
    Rails.logger.warn("rack-attack could not identify the caller (#{e.class})")
    nil
  end

  def self.anonymous?(request) = current_user_id(request).nil?

  def self.user_key(request)
    id = current_user_id(request)
    "user:#{id}" if id
  end

  # What the account behind this request is allowed to spend. Memoised for the
  # same reason the lookup above is, and failing to the free ceilings for the
  # same reason: a caller this middleware cannot identify must never end up
  # with a bigger budget than one it can.
  def self.plan(request)
    env = request.env
    return env[PLAN_KEY] if env.key?(PLAN_KEY)

    env[PLAN_KEY] = resolve_plan(request)
  end

  def self.resolve_plan(request)
    Plan.for(User.find_by(id: current_user_id(request)))
  rescue StandardError => e
    Rails.logger.warn("rack-attack could not read the caller's plan (#{e.class})")
    Plan.free
  end

  # Reading is cheap. Only guard it against something pathological.
  throttle("requests by ip", limit: 300, period: 5.minutes, &:ip)

  # TEMPLATE: the shape of a metered, plan-aware verb. The number is the
  # plan's; the key is not — a plan raises what an account may spend and never
  # changes whose budget it spends from. Point the path test at whatever this
  # product's expensive verb actually is, or delete the rule.
  #
  # Ordered cheapest-first on purpose: the verb test rejects nearly every
  # request before anything touches a cookie or the database, so the lookups
  # above are paid only on the handful of requests that can hit this ceiling.
  throttle("expensive writes by user",
           limit: ->(request) { plan(request).api_requests_per_hour }, period: 1.hour) do |request|
    user_key(request) if request.post? && request.path.start_with?("/api/")
  end

  # Anonymous callers get enough to try the product and no more. This is the
  # tier a rotating bot lands in, and the one worth keeping tight.
  throttle("expensive writes by anonymous ip", limit: 10, period: 1.hour) do |request|
    request.ip if request.post? && request.path.start_with?("/api/") && anonymous?(request)
  end

  # An account is free, so signing up is worth scripting; a sign-in form is
  # worth guessing at. Neither costs much per request, so these limits are
  # aimed at the loop rather than at the load.
  throttle("sign ups by ip", limit: 10, period: 1.hour) do |request|
    request.ip if request.post? && request.path == "/sign_up"
  end

  throttle("sign ins by ip", limit: 20, period: 15.minutes) do |request|
    request.ip if request.post? && request.path == "/sign_in"
  end

  # Per address as well as per IP: a distributed attempt on one known account
  # spends a different budget from a single host working through many.
  throttle("sign ins by email", limit: 10, period: 15.minutes) do |request|
    if request.post? && request.path == "/sign_in"
      request.params["email_address"].to_s.strip.downcase.presence
    end
  end

  # Turbo renders a 4xx response only when it is HTML. A text/plain 429 makes a
  # throttled submission do nothing at all — the visitor presses the button and
  # the page sits there. This runs as middleware, below the layout and below the
  # locale being set, so the page is built by hand and the locale is read off
  # the request.
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i

    # A programmatic caller parses JSON and cannot read a styled page. It gets
    # the header that says when to come back and nothing to render.
    if request.path.start_with?("/api/")
      next [ 429, { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
             [ { error: "rate_limited", retry_after: }.to_json ] ]
    end

    locale = LocaleNegotiation.resolve(
      requested: Rack::Utils.parse_nested_query(request.query_string)["locale"],
      accept_language: request.get_header("HTTP_ACCEPT_LANGUAGE")
    )

    body = I18n.with_locale(locale) do
      minutes = [ (retry_after / 60.0).ceil, 1 ].max

      <<~HTML
        <!DOCTYPE html>
        <html lang="#{locale}">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{ERB::Util.html_escape(I18n.t("errors.throttled.title"))}</title>
          <style>
            body { margin: 0; background: #faf9f7; color: #1a1a1a;
                   font: 16px/1.6 ui-sans-serif, system-ui, sans-serif; }
            main { max-width: 34rem; margin: 0 auto; padding: 6rem 1.5rem; }
            h1 { font-size: 2rem; letter-spacing: -0.02em; margin: 0 0 1rem; }
            p { margin: 0 0 1rem; color: #4a4a4a; }
            a { color: inherit; }
          </style>
        </head>
        <body>
          <main>
            <h1>#{ERB::Util.html_escape(I18n.t("errors.throttled.title"))}</h1>
            <p>#{ERB::Util.html_escape(I18n.t("errors.throttled.body", count: minutes))}</p>
            <p><a href="/?locale=#{locale}">#{ERB::Util.html_escape(I18n.t("errors.throttled.back"))}</a></p>
          </main>
        </body>
        </html>
      HTML
    end

    [ 429,
      { "Content-Type" => "text/html; charset=utf-8", "Retry-After" => retry_after.to_s },
      [ body ] ]
  end
end

# Health checks come from the proxy on every interval; counting them would
# throttle the container out of its own rotation.
Rack::Attack.safelist("health checks") { |request| request.path == "/up" }
