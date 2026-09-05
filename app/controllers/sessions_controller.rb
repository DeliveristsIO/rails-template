class SessionsController < ApplicationController
  include ChallengesHumans

  def new
  end

  def create
    user = User.authenticate_by(email_address: params[:email_address], password: params[:password])

    if user
      start_new_session_for(user)
      redirect_to after_authentication_path
    else
      # One message for a wrong password and for an address with no account:
      # the sign-in form must not become a way to ask whether somebody has an
      # account here.
      flash.now[:alert] = t(".failed")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to root_path
  end

  private
    # Only ever back into this app, and only to a path. `//host` and `/\host`
    # are how an absolute URL is usually smuggled past a "starts with a slash"
    # test, so both are refused.
    LOCAL_PATH = %r{\A/(?![/\\])}

    def after_authentication_path
      return_to = params[:return_to].to_s
      return_to.match?(LOCAL_PATH) ? return_to : root_path
    end
end
