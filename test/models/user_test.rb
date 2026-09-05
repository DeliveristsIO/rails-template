require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "an address that differs only in case or surrounding space is the same account" do
    User.create!(email_address: "Founder@Example.COM ", password: AuthenticationHelpers::PASSWORD)

    duplicate = User.new(email_address: " founder@example.com", password: AuthenticationHelpers::PASSWORD)

    assert_not duplicate.valid?
    assert_equal 1, User.where(email_address: "founder@example.com").count
  end

  # The standard regexp, which lets `founder@intranet` through: it is a valid
  # address, and a rule strict enough to catch every typo also refuses real
  # addresses. Whether one is deliverable is answered by sending to it.
  test "an address that is not an address is refused" do
    %w[ founder founder@ @example.com founder\ two@example.com ].each do |address|
      assert_not User.new(email_address: address, password: AuthenticationHelpers::PASSWORD).valid?,
        "#{address.inspect} should not pass for an email address"
    end
  end

  # BCrypt truncates silently past 72 bytes, so anything longer is a password
  # whose tail does nothing — better refused than quietly ignored.
  test "the password has both a floor and BCrypt's ceiling" do
    assert_not User.new(email_address: "a@example.com", password: "short").valid?
    assert_not User.new(email_address: "a@example.com", password: "x" * 73).valid?
    assert User.new(email_address: "a@example.com", password: "x" * 72).valid?
  end

  test "a new account is on the free plan without anything having to say so" do
    user = User.create!(email_address: "founder@example.com", password: AuthenticationHelpers::PASSWORD)

    assert_equal Plan::FREE, user.plan
    assert_not user.subscription_live?
    assert_equal Plan.free, user.current_plan
  end

  test "a plan the code does not define cannot be written to the column" do
    assert_not users(:reader).tap { |user| user.plan = "enterprise" }.valid?
  end

  # Closing the browser must not be the only way to end a session, and ending
  # an account must not leave a working one behind.
  test "deleting an account takes its sessions with it" do
    user = User.create!(email_address: "founder@example.com", password: AuthenticationHelpers::PASSWORD)
    user.sessions.create!

    assert_difference -> { Session.count }, -1 do
      user.destroy!
    end
  end
end
