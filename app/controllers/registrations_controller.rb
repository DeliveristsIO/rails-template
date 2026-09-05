class RegistrationsController < ApplicationController
  include ChallengesHumans

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    # An account is what raises a caller's budget, so minting them is worth
    # scripting exactly as much as the thing the budget buys.
    unless human?
      refuse_as_robot
      return render :new, status: :unprocessable_content
    end

    if @user.save
      start_new_session_for(@user)
      redirect_to root_path
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.expect(user: [ :email_address, :password ])
    end
end
