require "test_helper"

class PremiumContentTest < ActionDispatch::IntegrationTest
  test "premium content access" do
    get "/api/premium_content/paywalled_info"
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Premium content list", json_response["message"]
  end

  test "free content access" do
    get "/api/premium_content/free_info"
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "This is free content accessible to all users.", json_response["message"]
  end
end
