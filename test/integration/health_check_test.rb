require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "the healthcheck endpoint Kamal polls is green" do
    get "/up"
    assert_response :success
  end
end
