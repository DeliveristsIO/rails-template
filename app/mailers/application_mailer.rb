# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  # The relay only accepts an envelope sender on a domain it has been
  # authorised for, so this has to match whatever is configured in
  # config/environments/staging.rb rather than being anything readable.
  default from: ENV.fetch("MAIL_FROM", "skeleton@example.com")
  layout "mailer"
end
