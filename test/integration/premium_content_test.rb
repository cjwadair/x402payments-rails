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
    skip "temporarily disabled"
    invalid_payload = {foo: "bar"}.to_json
    encoded_signature = Base64.strict_encode64(invalid_payload)

    Api::PremiumContentController.any_instance.stub(:settle_payment, {"success" => false}) do
      get "/api/premium_content/paywalled_info", headers: {"PAYMENT-SIGNATURE" => encoded_signature}
      assert_response :payment_required

      payment_header = response.headers['PAYMENT-REQUIRED']
      assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"
      
      decoded_json = Base64.strict_decode64(payment_header)
      json_response = JSON.parse(decoded_json)
      
      assert_equal 2, json_response["x402Version"]
      assert json_response["accepts"].is_a?(Array)
      assert_not_empty json_response["accepts"]
    end
  end

  test "premium content access with valid PAYMENT-SIGNATURE allows access" do
    skip "temporarily disabled"
    valid_signature = Base64.strict_encode64({foo: "bar"}.to_json)

    settlement_request = {paymentPayload: {}, paymentRequirements: {}, success: true, payer: "0x123"}
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    facilitator_client = Minitest::Mock.new
    facilitator_client.expect(:verify_payment, {"success" => true, "payer" => "0x123"}, [Hash, Hash])
    facilitator_client.expect(:settle_payment, {"success" => true}, [Hash, Hash])

    Api::PremiumContentController.any_instance.stub(:settle_payment, {"success" => true}) do
      X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
        X402Payments::FacilitatorClient.stub :new, facilitator_client do
          get "/api/premium_content/paywalled_info", headers: {"PAYMENT-SIGNATURE" => valid_signature}
          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal "This is premium content that requires payment to access.", json_response["message"]
        end
      end
    end
  end

  test "free content access does not trigger paywall" do
    get "/api/premium_content/free_info"
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "This is free content accessible to all users.", json_response["message"]
  end
end
