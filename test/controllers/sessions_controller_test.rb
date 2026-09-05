require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signing in with the right password starts a session" do
    assert_difference -> { Session.count }, 1 do
      post sign_in_path, params: { email_address: users(:reader).email_address,
                                   password: AuthenticationHelpers::PASSWORD }
    end

    assert_redirected_to root_path
  end

  test "the address is matched the way it is stored, whatever was typed" do
    post sign_in_path, params: { email_address: "  Reader@Example.COM ",
                                 password: AuthenticationHelpers::PASSWORD }

    assert_redirected_to root_path
  end

  # A sign-in form that answers "no such account" differently from "wrong
  # password" is a way to ask whether a given person has an account here.
  test "a wrong password and an unknown address fail identically" do
    post sign_in_path, params: { email_address: users(:reader).email_address, password: "not the password" }
    wrong_password = response.body

    post sign_in_path, params: { email_address: "nobody@example.com", password: "not the password" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sessions.create.failed")
    assert_includes wrong_password, I18n.t("sessions.create.failed")
  end

  test "a failed sign-in starts no session" do
    assert_no_difference -> { Session.count } do
      post sign_in_path, params: { email_address: users(:reader).email_address, password: "not the password" }
    end
  end

  test "signing out ends the session record, not just the cookie" do
    sign_in_as

    assert_difference -> { Session.count }, -1 do
      delete sign_out_path
    end

    assert_redirected_to root_path
  end

  # `return_to` is written by whoever wrote the link, so an open redirect here
  # sends a freshly signed-in visitor to somebody else's page.
  test "it returns only to a path inside this app" do
    inside = subscription_path

    post sign_in_path, params: { email_address: users(:reader).email_address,
                                 password: AuthenticationHelpers::PASSWORD, return_to: inside }
    assert_redirected_to inside

    [ "https://evil.example.com/steal", "//evil.example.com", "/\\evil.example.com" ].each do |hostile|
      delete sign_out_path
      post sign_in_path, params: { email_address: users(:reader).email_address,
                                   password: AuthenticationHelpers::PASSWORD, return_to: hostile }

      assert_redirected_to root_path, "#{hostile.inspect} must not be somewhere this app sends anybody"
    end
  end
end
