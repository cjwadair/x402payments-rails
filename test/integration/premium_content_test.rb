require "test_helper"

class PremiumContentTest < ActionDispatch::IntegrationTest
  test "premium content access triggers paywall if PAYMENT-SIGNATURE header is missing" do
    get "/api/premium_content/paywalled_info"
    assert_response :payment_required

    # Decode the base64-encoded PAYMENT-REQUIRED header
    payment_header = response.headers["PAYMENT-REQUIRED"]
    assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"

    decoded_json = Base64.strict_decode64(payment_header)
    json_response = JSON.parse(decoded_json)

    assert_equal 2, json_response["x402Version"]
    assert json_response["accepts"].is_a?(Array)
    assert_not_empty json_response["accepts"]
  end

  test "calling require_x402_payment with invalid payment options raises error" do
    with_paywall_options({}) do
      error = assert_raises(ArgumentError) do
        get "/api/premium_content/invalid_payment_info"
      end

      assert_match(/amount is required/i, error.message)
    end
  end

  test "calling require_x402_payment with nil amount raises error" do
    with_paywall_options({ amount: nil }) do
      error = assert_raises(ArgumentError) do
        get "/api/premium_content/invalid_payment_info"
      end

      assert_match(/amount is required/i, error.message)
    end
  end

  test "calling require_x402_payment with invalid amount type raises invalid options error" do
    with_paywall_options({ amount: "abc" }) do
      error = assert_raises(ArgumentError) do
        get "/api/premium_content/invalid_payment_info"
      end

      assert_match(/invalid payment options: amount must be a number, got: "abc"/i, error.message)
    end
  end

  test "calling require_x402_payment with negative amount raises invalid options error" do
    with_paywall_options({ amount: -1 }) do
      error = assert_raises(ArgumentError) do
        get "/api/premium_content/invalid_payment_info"
      end

      assert_match(/invalid payment options: amount must be positive, got: -1/i, error.message)
    end
  end

  test "premium content access with invalid PAYMENT-SIGNATURE triggers paywall" do
    invalid_payload = { foo: "bar" }.to_json
    encoded_signature = Base64.strict_encode64(invalid_payload)

    get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => encoded_signature }
    assert_response :payment_required

    payment_header = response.headers["PAYMENT-REQUIRED"]
    assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"

    decoded_json = Base64.strict_decode64(payment_header)
    json_response = JSON.parse(decoded_json)

    assert_equal 2, json_response["x402Version"]
    assert json_response["accepts"].is_a?(Array)
    assert_not_empty json_response["accepts"]
  end

  test "premium content access with valid PAYMENT-SIGNATURE allows access" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {}, success: true, payer: "0x123" }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    facilitator_client = Minitest::Mock.new
    facilitator_client.expect(:verify_payment, { "success" => true, "payer" => "0x123" }, [ Hash, Hash ])
    facilitator_client.expect(:settle_payment, { "success" => true }, [ Hash, Hash ])

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }
        assert_response :success
        json_response = JSON.parse(response.body)
        assert_equal "This is premium content that requires payment to access.", json_response["message"]
      end
      end
  end

  test "premium content access with SettlementRequest raising StandardError triggers paywall with error message" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    # Create a simple object that raises StandardError when generate is called
    settlement_request_double = Object.new
    def settlement_request_double.generate
      raise StandardError, "Unexpected database error"
    end

    # Stub SettlementRequest.new to return the object (needs to accept arguments)
    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, ->(*args) { settlement_request_double } do
      get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

      assert_response :payment_required

      # Verify the PAYMENT-REQUIRED header is present
      payment_header = response.headers["PAYMENT-REQUIRED"]
      assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"

      # Decode and verify the error message
      decoded_json = Base64.strict_decode64(payment_header)
      json_response = JSON.parse(decoded_json)

      assert_equal "Payment processing error", json_response["error"]
    end
  end

  test "premium content access with FacilitatorClient verify_payment raising InvalidPaymentError triggers paywall" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {} }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    # Create a simple object that raises InvalidPaymentError
    facilitator_client = Object.new
    def facilitator_client.verify_payment(*args)
      raise X402Payments::InvalidPaymentError, "Payment signature is invalid"
    end

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

        assert_response :payment_required

        payment_header = response.headers["PAYMENT-REQUIRED"]
        assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"
      end
    end
  end

  test "premium content access with FacilitatorClient verify_payment raising FacilitatorError triggers paywall" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {} }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    # Create a simple object that raises FacilitatorError
    facilitator_client = Object.new
    def facilitator_client.verify_payment(*args)
      raise X402Payments::FacilitatorError, "Facilitator service unavailable"
    end

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

        assert_response :payment_required

        payment_header = response.headers["PAYMENT-REQUIRED"]
        assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"
      end
    end
  end

  test "premium content access with FacilitatorClient verify_payment raising StandardError triggers paywall" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {} }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    # Create a simple object that raises RuntimeError (StandardError)
    facilitator_client = Object.new
    def facilitator_client.verify_payment(*args)
      raise RuntimeError, "Unexpected network error"
    end

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

        assert_response :payment_required

        payment_header = response.headers["PAYMENT-REQUIRED"]
        assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"
      end
    end
  end

  test "premium content access with FacilitatorClient settle_payment raising FacilitatorError triggers paywall in non-optimistic mode" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {} }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    # Create a facilitator client that succeeds at verify but fails at settle
    facilitator_client = Object.new
    def facilitator_client.verify_payment(*args)
      { "success" => true, "payer" => "0x123" }
    end
    def facilitator_client.settle_payment(*args)
      raise X402Payments::FacilitatorError, "Settlement service unavailable"
    end

    # Ensure optimistic mode is false (default)
    original_optimistic = X402Payments.configuration.optimistic
    X402Payments.configuration.optimistic = false

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

        assert_response :payment_required

        payment_header = response.headers["PAYMENT-REQUIRED"]
        assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"
      end
    end
  ensure
    X402Payments.configuration.optimistic = original_optimistic
  end

  test "premium content access with FacilitatorClient settle_payment raising StandardError triggers paywall in non-optimistic mode" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {} }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    # Create a facilitator client that succeeds at verify but fails at settle with StandardError
    facilitator_client = Object.new
    def facilitator_client.verify_payment(*args)
      { "success" => true, "payer" => "0x123" }
    end
    def facilitator_client.settle_payment(*args)
      raise RuntimeError, "Database connection lost"
    end

    # Ensure optimistic mode is false (default)
    original_optimistic = X402Payments.configuration.optimistic
    X402Payments.configuration.optimistic = false

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

        assert_response :payment_required

        payment_header = response.headers["PAYMENT-REQUIRED"]
        assert_not_nil payment_header, "PAYMENT-REQUIRED header should be present"
      end
    end
  ensure
    X402Payments.configuration.optimistic = original_optimistic
  end

  test "premium content access with FacilitatorClient settle_payment raising FacilitatorError allows access in optimistic mode" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {} }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    # Create a facilitator client that succeeds at verify but fails at deferred settle
    facilitator_client = Object.new
    def facilitator_client.verify_payment(*args)
      { "success" => true, "payer" => "0x123" }
    end
    def facilitator_client.settle_payment(*args)
      raise X402Payments::FacilitatorError, "Settlement service unavailable"
    end

    # Enable optimistic mode
    original_optimistic = X402Payments.configuration.optimistic
    X402Payments.configuration.optimistic = true

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

        # In optimistic mode, access is granted even if settlement fails
        assert_response :success
        json_response = JSON.parse(response.body)
        assert_equal "This is premium content that requires payment to access.", json_response["message"]
      end
    end
  ensure
    X402Payments.configuration.optimistic = original_optimistic
  end

  test "premium content access with FacilitatorClient settle_payment raising StandardError allows access in optimistic mode" do
    valid_signature = Base64.strict_encode64({ foo: "bar" }.to_json)

    settlement_request = { paymentPayload: {}, paymentRequirements: {} }
    settlement_request_double = Minitest::Mock.new
    settlement_request_double.expect(:generate, settlement_request)

    # Create a facilitator client that succeeds at verify but fails at deferred settle with StandardError
    facilitator_client = Object.new
    def facilitator_client.verify_payment(*args)
      { "success" => true, "payer" => "0x123" }
    end
    def facilitator_client.settle_payment(*args)
      raise RuntimeError, "Database connection lost"
    end

    # Enable optimistic mode
    original_optimistic = X402Payments.configuration.optimistic
    X402Payments.configuration.optimistic = true

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_request_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => valid_signature }

        # In optimistic mode, access is granted even if settlement fails
        assert_response :success
        json_response = JSON.parse(response.body)
        assert_equal "This is premium content that requires payment to access.", json_response["message"]
      end
    end
  ensure
    X402Payments.configuration.optimistic = original_optimistic
  end

  test "free content access does not trigger paywall" do
    get "/api/premium_content/free_info"
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "This is free content accessible to all users.", json_response["message"]
  end

  test "invalid payment header triggers expected error" do
    invalid_signature = "not-a-valid-base64"
    error = assert_raises(RuntimeError) do
      get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => invalid_signature }
    end
    assert_match(/invalid payment signature header:/i, error.message)
  end

  private

  def with_paywall_options(temp_options)
    controller_class = Api::PremiumContentController
    original_paywall_options = controller_class.instance_method(:paywall_options)

    controller_class.define_method(:paywall_options) { temp_options }
    yield
  ensure
    controller_class.define_method(:paywall_options, original_paywall_options)
  end
end
