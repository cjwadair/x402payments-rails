require "test_helper"

class PremiumContentTest < ActionDispatch::IntegrationTest
  test "premium content access triggers paywall" do
    get "/api/premium_content/paywalled_info"
    assert_response :payment_required

    json_response = JSON.parse(response.body)
    assert_equal 2, json_response["x402Version"]
    assert json_response["accepts"].is_a?(Array)
    assert_not_empty json_response["accepts"]
  end

  test "free content access does not trigger paywall" do
    get "/api/premium_content/free_info"
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "This is free content accessible to all users.", json_response["message"]
  end
end
