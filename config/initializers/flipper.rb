# frozen_string_literal: true

# Feature flags, stored in the same database as everything else.
Flipper.configure do |config|
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end

# The mounted UI, wrapped in basic auth. It can switch parts of the product off
# for every visitor, so it is not something to leave open on a public host —
# and when no credentials are configured it serves nothing at all rather than
# accepting an empty password.
module FlipperGate
  REALM = "skeleton"

  def self.app
    Rack::Builder.new do
      use Rack::Auth::Basic, REALM do |username, password|
        FlipperGate.authorised?(username, password)
      end

      run Flipper::UI.app(Flipper)
    end
  end

  def self.authorised?(username, password)
    expected_user = ENV["FLIPPER_USERNAME"]
    expected_password = ENV["FLIPPER_PASSWORD"]
    return false if expected_user.blank? || expected_password.blank?

    # Both comparisons always run: returning early on the username would leak
    # which half was wrong through timing.
    ActiveSupport::SecurityUtils.secure_compare(username.to_s, expected_user) &
      ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
  end
end
