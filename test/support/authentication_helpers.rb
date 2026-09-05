module AuthenticationHelpers
  PASSWORD = "correct horse battery"

  # Signs in over the real form, so a test that passes here is a test that the
  # form works the way a visitor works it.
  def sign_in_as(user = users(:reader))
    post sign_in_path, params: { email_address: user.email_address, password: PASSWORD }
    assert_response :redirect
    user
  end
end
