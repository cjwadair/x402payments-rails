require "test_helper"

class SettlementRequestTest < ActiveSupport::TestCase

  def setup
    @valid_payload = {
      x402Version: 2,
      payload: {
        authorization: {
          from: "0x07B88Fa6bAA91384D07Ae419a08FdeC7e8908D2e",
          to: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
          value: "1000",
          validAfter: "1769958357",
          validBefore: "1769959257",
          nonce: "0x34567890123456..."
        },      
        signature: "0x1234567890abcdef..."
      },
      resource: {
        url: "https://example.com/protected_resource",
        description: "Access to protected resource",
        mimeType: "application/json"
      },
      accepted: {
        scheme: "exact", 
        network: "eip155:84532", 
        amount: "1000", 
        asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        payTo: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
        maxTimeoutSeconds: 600,
        extra: {name: "USDC", version: "2"}
      }
    }
    @accepted_payments = [
      {
        scheme: "exact", 
        network: "eip155:84532", 
        amount: "1000", 
        asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        payTo: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
        maxTimeoutSeconds: 600,
        extra: {name: "USDC", version: "2"}
      }
    ]
  end

  test "generates valid settlement request with correct structure" do
    settlement_request = X402Payments::FacilitatorMessaging::SettlementRequest.new(@valid_payload, @accepted_payments).generate

    puts "settlement_request: #{settlement_request.inspect}"

    assert_equal 2, settlement_request[:x402Version]
    assert settlement_request[:paymentPayload].is_a?(Hash)
    assert settlement_request[:paymentRequirements].is_a?(Hash)
  end

  test "paymentPayload has correct keys" do
    settlement_request = X402Payments::FacilitatorMessaging::SettlementRequest.new(@valid_payload, @accepted_payments).generate
    assert_equal settlement_request[:paymentPayload].keys, [:x402Version, :accepted, :payload, :extensions, :resource]
  end

  test "paymentRequirements matches accepted payment" do
    settlement_request = X402Payments::FacilitatorMessaging::SettlementRequest.new(@valid_payload, @accepted_payments).generate
    assert_equal @accepted_payments.first, settlement_request[:paymentRequirements]
  end

  test "raises error for missing accepted payment info in payload" do
    invalid_payload = @valid_payload.dup
    invalid_payload.delete(:accepted)
    assert_raises(X402Payments::FacilitatorMessaging::InvalidSettlementRequestError) do
      X402Payments::FacilitatorMessaging::SettlementRequest.new(invalid_payload, @accepted_payments).generate
    end
  end

  test "raises error when payload accepted does not match accepted payments" do
    mismatched_payload = @valid_payload.dup
    mismatched_payload[:accepted] = {
      scheme: "exact", 
      network: "eip155:43114", # Different network - doesn't match accepted_payments
      amount: "1000", 
      asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      payTo: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
      maxTimeoutSeconds: 600,
      extra: {name: "USDC", version: "2"}
    }
    assert_raises(X402Payments::FacilitatorMessaging::InvalidSettlementRequestError) do
      X402Payments::FacilitatorMessaging::SettlementRequest.new(mismatched_payload, @accepted_payments).generate
    end
  end

  test "raises error for missing authorization in payload" do
    invalid_payload = @valid_payload.dup
    invalid_payload[:payload].delete(:authorization)

    assert_raises(X402Payments::FacilitatorMessaging::InvalidSettlementRequestError) do
      X402Payments::FacilitatorMessaging::SettlementRequest.new(invalid_payload, @accepted_payments).generate
    end
  end

  test "raises error for recipient mismatch" do
    invalid_payload = @valid_payload.dup
    invalid_payload[:payload][:authorization][:to] = "0xWrongRecipientAddress"
    assert_raises(X402Payments::FacilitatorMessaging::InvalidSettlementRequestError) do
      X402Payments::FacilitatorMessaging::SettlementRequest.new(invalid_payload, @accepted_payments).generate
    end
  end

  test "raises error for insufficient amount" do
    invalid_payload = @valid_payload.dup
    invalid_payload[:payload][:authorization][:value] = "500" # Less than required 1000
    assert_raises(X402Payments::FacilitatorMessaging::InvalidSettlementRequestError) do
      X402Payments::FacilitatorMessaging::SettlementRequest.new(invalid_payload, @accepted_payments).generate
    end
  end

  test "raises error when no matching accepted payment is found" do
    invalid_accepted_payments = [
      {
        scheme: "exact", 
        network: "eip155:43114", # Different network
        amount: "1000", 
        asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        payTo: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
        max_timeout_seconds: 600,
        extra: {name: "USDC", version: "2"}
      }
    ]
    assert_raises(X402Payments::FacilitatorMessaging::InvalidSettlementRequestError) do
      X402Payments::FacilitatorMessaging::SettlementRequest.new(@valid_payload, invalid_accepted_payments).generate
    end
  end

end