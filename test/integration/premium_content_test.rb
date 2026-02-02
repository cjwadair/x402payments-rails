require "test_helper"

class PremiumContentTest < ActionDispatch::IntegrationTest
  test "premium content access triggers paywall if PAYMENT-SIGNATURE header is missing" do
    get "/api/premium_content/paywalled_info"
    assert_response :payment_required

    # Decode the base64-encoded PAYMENT-REQUIRED header
    payment_header = response.headers['PAYMENT-REQUIRED']
    assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"
    
    decoded_json = Base64.strict_decode64(payment_header)
    json_response = JSON.parse(decoded_json)
    
    assert_equal 2, json_response["x402Version"]
    assert json_response["accepts"].is_a?(Array)
    assert_not_empty json_response["accepts"]
  end

  test "premium content access with invalid PAYMENT-SIGNATURE triggers paywall" do
    skip "Implement payment signature generation and verification logic"
  end

  test "free content access does not trigger paywall" do
    get "/api/premium_content/free_info"
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "This is free content accessible to all users.", json_response["message"]
  end
end
