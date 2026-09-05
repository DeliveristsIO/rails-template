# The forms that cost something to submit, and the ones a rotating address
# makes free. Every one of them asks the same question in the same place.
module ChallengesHumans
  extend ActiveSupport::Concern

  private
    def human?
      Turnstile.human?(token: params[Turnstile::FIELD], ip: request.remote_ip)
    end

    # Refusing is a normal outcome of a form, so it comes back as the form with
    # a message on it rather than as an error page.
    def refuse_as_robot
      flash.now[:alert] = t("errors.challenge_failed")
    end
end
