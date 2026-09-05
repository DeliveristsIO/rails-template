class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  private
    # Every value the header takes: do not index it, do not follow out of it,
    # do not keep a cached copy, do not quote it in a result.
    #
    # A header rather than a robots.txt Disallow, and this is the whole reason:
    # a crawler told not to fetch the page never reads the instruction on it,
    # and indexes the bare URL anyway on the strength of an inbound link.
    # Staying crawlable is what makes the instruction arrive.
    NO_INDEX = "noindex, nofollow, noarchive, nosnippet"

    def discourage_indexing
      response.headers["X-Robots-Tag"] = NO_INDEX
    end

    # The rule itself lives in LocaleNegotiation, because the throttled response
    # is rendered by middleware that never reaches a controller and still has to
    # answer in the visitor's language.
    def switch_locale(&)
      locale = LocaleNegotiation.resolve(
        requested: params[:locale], accept_language: request.get_header("HTTP_ACCEPT_LANGUAGE")
      )

      I18n.with_locale(locale, &)
    end
end
