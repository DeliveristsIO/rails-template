# The Rails 8 session shape, kept deliberately small. Most of this app is
# public — a name checker nobody can use without an account has no funnel — so
# the concern's job is to know *who* is asking rather than to keep anyone out.
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :session_id

  included do
    before_action :resume_session
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def require_authentication(**options)
      before_action :request_authentication, **options
    end
  end

  private
    def resume_session
      Current.session = find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[SESSION_COOKIE]) if cookies.signed[SESSION_COOKIE]
    end

    def authenticated?
      Current.session.present?
    end

    def current_user
      Current.user
    end

    # Hung on individual actions by the class-level `require_authentication`.
    # `resume_session` has already run by this point, so the only question
    # left is whether it found anything — without this guard the filter turns
    # every action it protects into a redirect, signed in or not.
    def request_authentication
      return if authenticated?

      # Without the return_to, being asked to sign in costs you the page you
      # asked for: you land on the root and have to find it again. Only a
      # readable verb is worth returning to — HEAD included, since a router
      # sends it down the same path as GET.
      redirect_to sign_in_path(return_to: (request.fullpath if request.get? || request.head?)), alert: t("sessions.required")
    end

    def start_new_session_for(user)
      user.sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent).tap do |session|
        Current.session = session
        cookies.signed.permanent[SESSION_COOKIE] =
          { value: session.id, httponly: true, same_site: :lax, secure: request.ssl? }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(SESSION_COOKIE)
      Current.session = nil
    end
end
