# frozen_string_literal: true

# EN/DE/PL from the first view. `?locale=` wins so a link can pin one;
# otherwise the browser decides, which is what a founder in Warsaw or Berlin
# arriving at a shared link actually wants.
#
# It lives here rather than in ApplicationController because rack-attack's
# throttled response is rendered by middleware, below the controller and below
# `around_action :switch_locale` — and a throttled visitor deserves the same
# language as an admitted one.
module LocaleNegotiation
  module_function

  def available
    I18n.available_locales.map(&:to_s)
  end

  def resolve(requested: nil, accept_language: nil)
    pinned(requested) || preferred(accept_language) || I18n.default_locale.to_s
  end

  def pinned(requested)
    requested.to_s.presence_in(available)
  end

  def preferred(accept_language)
    accept_language.to_s.scan(/[a-z]{2}(?=[-;,]|$)/i).map(&:downcase).find { |tag| available.include?(tag) }
  end
end
