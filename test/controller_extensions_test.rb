require "test_helper"

# Tests for behaviour specific to ControllerExtensions that is not already
# covered by the broader integration suite in test/integration/premium_content_test.rb.
class ControllerExtensionsTest < ActionDispatch::IntegrationTest
  VALID_SIGNATURE = Base64.strict_encode64({ foo: "bar" }.to_json)
  STUB_SETTLEMENT_REQUEST = { paymentPayload: {}, paymentRequirements: {} }.freeze

  test "successful settlement sets PAYMENT-RESPONSE header" do
    settlement_double = stub_settlement_request

    facilitator_client = Minitest::Mock.new
    facilitator_client.expect(:verify_payment, { "success" => true, "payer" => "0x123" }, [ Hash, Hash ])
    facilitator_client.expect(:settle_payment, { "success" => true, "txHash" => "0xabc" }, [ Hash, Hash ])

    X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_double do
      X402Payments::FacilitatorClient.stub :new, facilitator_client do
        get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => VALID_SIGNATURE }

        assert_response :success
        assert_not_nil response.headers["PAYMENT-RESPONSE"], "PAYMENT-RESPONSE header should be set"
        decoded = JSON.parse(Base64.strict_decode64(response.headers["PAYMENT-RESPONSE"]))
        assert_equal true, decoded["success"]
      end
    end
  end

  test "settlement returning success false triggers 402 in non-optimistic mode" do
    settlement_double = stub_settlement_request

    facilitator_client = build_facilitator_client(
      verify_result: { "success" => true, "payer" => "0x123" },
      settle_result: { "success" => false, "error" => "insufficient funds" }
    )

    with_optimistic(false) do
      X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_double do
        X402Payments::FacilitatorClient.stub :new, facilitator_client do
          get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => VALID_SIGNATURE }

          assert_response :payment_required
          assert_not_nil response.headers["PAYMENT-REQUIRED"]
          assert_nil response.headers["PAYMENT-RESPONSE"]
        end
      end
    end
  end

  test "settlement returning success false still allows access in optimistic mode" do
    settlement_double = stub_settlement_request

    facilitator_client = build_facilitator_client(
      verify_result: { "success" => true, "payer" => "0x123" },
      settle_result: { "success" => false, "error" => "insufficient funds" }
    )

    with_optimistic(true) do
      X402Payments::FacilitatorMessaging::SettlementRequest.stub :new, settlement_double do
        X402Payments::FacilitatorClient.stub :new, facilitator_client do
          get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => VALID_SIGNATURE }

          assert_response :success
          json = JSON.parse(response.body)
          assert_equal "This is premium content that requires payment to access.", json["message"]
        end
      end
    end
  end

  test "malformed payment header returns 402 not 500" do
    malformed_header = Base64.strict_encode64("this is not valid json {{{")

    get "/api/premium_content/paywalled_info", headers: { "PAYMENT-SIGNATURE" => malformed_header }

    assert_response :payment_required
    assert_not_nil response.headers["PAYMENT-REQUIRED"]
  end

  private

  def stub_settlement_request
    double = Minitest::Mock.new
    double.expect(:generate, STUB_SETTLEMENT_REQUEST)
    double
  end

  def build_facilitator_client(verify_result:, settle_result:)
    client = Object.new
    client.define_singleton_method(:verify_payment) { |*| verify_result }
    client.define_singleton_method(:settle_payment) { |*| settle_result }
    client
  end

  def with_optimistic(value)
    original = X402Payments.configuration.optimistic
    X402Payments.configuration.optimistic = value
    yield
  ensure
    X402Payments.configuration.optimistic = original
  end
end
