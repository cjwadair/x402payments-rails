require "test_helper"

class FacilitatorClientTest < ActiveSupport::TestCase
  def setup
    @client = X402Payments::FacilitatorClient.new

    @payload = {
      x402Version: 2,
      payload:{
        authorization:{
          from: "0x07B88Fa6bAA91384D07Ae419a08FdeC7e8908D2e",
          to: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
          value: "1000",
          validAfter: "1769958357",
          validBefore: "1769959257",
          nonce: "0x34567890123456..."
        },			
        signature:"0x1234567890abcdef..."	
      },
      resource:{
        url: "https://example.com/protected_resource",
        description: "Access to protected resource",
        mimeType: "application/json"
      },
      accepted:{
        scheme: "exact", 
        network: "eip155:84532", 
        amount: "1000", 
        asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        payTo: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
        maxTimeoutSeconds: 600,
        extra:{name: "USDC", version: "2"}
      },
      extensions: {}
    }

    @payment_requirements = {
      scheme: "exact", 
      network: "eip155:84532", 
      amount: "1000", 
      asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      payTo: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
      max_timeout_seconds: 600,
      extra: {name: "USDC", version: "2"}
    }

    @expected_response_body = {		
      success:true,
      transaction:"0x086c2fe816640bd...",
      network:"eip155:84532",
      payer:"0x07B88Fa6bAA91384D07A..."
    }
  end

  test "fetches supported networks from facilitator" do
    # Stub the facilitator response
    stub_request(:get, "#{X402Payments.configuration.facilitator_url}/supported")
      .to_return(
        status: 200, 
        body: {
          kinds: ["eip155:84532"],
          extensions: [],
          signers: {
            "eip155:84532" => {
              address: "0x123...",
              type: "contract"
            }
          }
        }.to_json
      )
    
    response = @client.supported_networks
    
    # Structure
    assert response.is_a?(Hash)
    assert_not_empty response
    assert_equal ["kinds", "extensions", "signers"].sort, response.keys.sort
    
    # Kinds (payment types/networks)
    assert response["kinds"].is_a?(Array)
    assert_not_empty response["kinds"], "Should have at least one supported network"
    
    # Signers
    assert response["signers"].is_a?(Hash)
    assert_not_empty response["signers"], "Should have signers configured"
    
    # Extensions
    assert response["extensions"].is_a?(Array)
  end

  test "raises FacilitatorError if FaradayError returned when fetching supported networks" do
    stub_request(:get, "#{X402Payments.configuration.facilitator_url}/supported")
      .to_timeout
    
    error = assert_raises X402Payments::FacilitatorError do
      @client.supported_networks
    end
    assert_match(/Failed to fetch supported networks:/, error.message)
  end
    
  test "handles 500 series errors correctly" do
    stub_request(:get, "#{X402Payments.configuration.facilitator_url}/supported")
      .to_return(status: 500)
    
    error = assert_raises X402Payments::FacilitatorError do
      @client.supported_networks
    end
    
    assert_match(/Facilitator error \(supported\): 500/, error.message)
  end

  test "400 response raises expected error correctly" do
    stub_request(:get, "#{X402Payments.configuration.facilitator_url}/supported")
      .to_return(status: 400, body: { error: "Bad Request" }.to_json)

    error = assert_raises X402Payments::InvalidPaymentError do
      @client.supported_networks
    end
    
    assert_match(/Invalid payment: Bad Request/, error.message)
  end

  test 'handles unexpected response codes correctly' do
    stub_request(:get, "#{X402Payments.configuration.facilitator_url}/supported")
      .to_return(status: 302)
    
    error = assert_raises X402Payments::FacilitatorError do
      @client.supported_networks
    end
    
    assert_match(/Unexpected response \(supported\): 302/, error.message)
  end

  test "handles invalid JSON response correctly" do
    stub_request(:get, "#{X402Payments.configuration.facilitator_url}/supported")
      .to_return(status: 200, body: "Invalid JSON") 
    
    error = assert_raises X402Payments::FacilitatorError do
      @client.supported_networks
    end
    
    assert_match(/Failed to parse facilitator response/, error.message)
  end

  test "builds payment verification request and receives valid response" do
    VCR.turned_off do
      stub_request(:post, "#{X402Payments.configuration.facilitator_url}/verify")
        .to_return(status: 200, body: @expected_response_body.to_json)
        
      response = @client.verify_payment(@payload, @payment_requirements)
      assert response.is_a?(Hash)
      assert_equal response.keys.sort, ["success", "transaction", "network", "payer"].sort
    end
  end

  test "raises validator error if FaradayError returned when verifying payment" do
    stub_request(:post, "#{X402Payments.configuration.facilitator_url}/verify")
      .to_timeout
    
    error = assert_raises X402Payments::FacilitatorError do
      @client.verify_payment(@payload, @payment_requirements)
    end
    
    assert_match(/Failed to verify payment:/, error.message)
  end
  
  test "builds payment request and receives valid response when submitting payment" do
    VCR.turned_off do
      stub_request(:post, "#{X402Payments.configuration.facilitator_url}/settle")
        .to_return(status: 200, body: @expected_response_body.to_json)
        
      response = @client.settle_payment(@payload, @payment_requirements)
      assert response.is_a?(Hash)
      assert_equal response["success"], true
    end
  end

  test "raises FacilitatorError if FaradayError returned when submitting payment" do
    stub_request(:post, "#{X402Payments.configuration.facilitator_url}/settle")
      .to_timeout
    error = assert_raises X402Payments::FacilitatorError do
      @client.settle_payment(@payload, @payment_requirements)
    end
    assert_match(/Failed to settle payment:/, error.message)
  end

  test "sends payment processing request and receives valid response" do
    skip "temporarily disabled"
    payment_processing_options = {
      scheme: "exact",
      network: "base-sepolia",
      amount: 0.01,
      asset: "USDC",
      payTo: "0xFacilitatorAddress",
      maxTimeoutSeconds: 300
    }

    VCR.use_cassette("facilitator_payment_processing") do
      response = @client.send_payment_processing_request(payment_processing_options)

      assert response.is_a?(Hash)
      assert response[:status] == "success"
      assert response[:paymentDetails].is_a?(Hash)
      assert response[:paymentDetails][:transactionHash].present?
    end
  end

  test "raises error when verify response is missing payer field" do
    invalid_response = {
      success: true,
      transaction: "0x086c2fe816640bd...",
      network: "eip155:84532"
      # payer field is missing
    }

    stub_request(:post, "#{X402Payments.configuration.facilitator_url}/verify")
      .to_return(status: 200, body: invalid_response.to_json)
    
    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(@payload, @payment_requirements)
    end
    
    assert_match(/no payer address returned/, error.message)
  end

  test "raises error when verify response indicates validation failed" do
    invalid_response = {
      isValid: false,
      invalidReason: "Insufficient funds",
      payer: "0x07B88Fa6bAA91384D07A..."
    }

    stub_request(:post, "#{X402Payments.configuration.facilitator_url}/verify")
      .to_return(status: 200, body: invalid_response.to_json)
    
    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(@payload, @payment_requirements)
    end
    
    assert_match(/Facilitator validation failed: Insufficient funds/, error.message)
  end

  test "raises error when verify response has success false" do
    invalid_response = {
      success: false,
      error: "Invalid signature",
      payer: "0x07B88Fa6bAA91384D07A..."
    }

    stub_request(:post, "#{X402Payments.configuration.facilitator_url}/verify")
      .to_return(status: 200, body: invalid_response.to_json)
    
    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(@payload, @payment_requirements)
    end
    
    assert_match(/Facilitator validation failed: Invalid signature/, error.message)
  end

  # Request validation tests
  test "raises error when payment payload is nil" do
    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(nil, @payment_requirements)
    end
    
    assert_match(/Payment payload cannot be nil/, error.message)
  end

  test "raises error when payment payload is not a hash" do
    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment("invalid", @payment_requirements)
    end
    
    assert_match(/Payment payload must be a Hash/, error.message)
  end

  test "raises error when payment payload missing accepted" do
    invalid_payload = { payload:{signature: "0x123..."} }

    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(invalid_payload, @payment_requirements)
    end

    assert_match(/Payment payload missing 'accepted'/, error.message)
  end

  test "raises error when payment payload missing payload section" do
    invalid_payload = { accepted: @payload[:accepted] }

    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(invalid_payload, @payment_requirements)
    end

    assert_match(/Payment payload missing 'payload'/, error.message)
  end

  test "raises error when payment payload[:payload] is not a hash" do
    invalid_payload = { payload: "invalid", accepted: @payload[:accepted] }

    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(invalid_payload, @payment_requirements)
    end

    assert_match(/Payment payload 'payload' must be a Hash/, error.message)
  end

  test "raises error when payment payload accepted is not a hash" do
    invalid_payload = { payload: @payload[:payload], accepted: "invalid" }

    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(invalid_payload, @payment_requirements)
    end

    assert_match(/Payment payload 'accepted' must be a Hash/, error.message)
  end

  test "raises error when payment requirements is nil" do
    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(@payload, nil)
    end
    
    assert_match(/Payment requirements cannot be nil/, error.message)
  end

  test "raises error when payment requirements missing required field" do
    invalid_requirements = {
      scheme: "exact",
      network: "eip155:84532",
      amount: "1000",
      # asset is missing
      payTo: "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D"
    }
    
    error = assert_raises X402Payments::InvalidPaymentError do
      @client.verify_payment(@payload, invalid_requirements)
    end
    
    assert_match(/Payment requirements missing required field 'asset'/, error.message)
  end


  test "validation accepts string keys in addition to symbol keys" do
    skip "temporarily disabled"
    string_payload = {
      "x402Version" => 2,
      "payload" => {
        "authorization" => {
          "from" => "0x07B88Fa6bAA91384D07Ae419a08FdeC7e8908D2e",
          "to" => "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
          "value" => "1000",
          "validAfter" => "1769958357",
          "validBefore" => "1769959257",
          "nonce" => "0x34567890123456..."
        },
        "signature" => "0x1234567890abcdef..."
      },
      "resource" => {
        "url" => "https://example.com/protected_resource",
        "description" => "Access to protected resource",
        "mimeType" => "application/json"
      },
      "accepted" => {
        "scheme" => "exact", 
        "network" => "eip155:84532",
        "amount" => "1000", 
        "asset" => "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        "payTo" => "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
        "maxTimeoutSeconds" => 600,
        "extra" => {"name" => "USDC", "version" => "2"}
      },
      "extensions" => {}
    }
    
    string_requirements = {
      "scheme" => "exact",
      "network" => "eip155:84532",
      "amount" => "1000",
      "asset" => "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      "payTo" => "0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D"
    }
    
    stub_request(:post, "#{X402Payments.configuration.facilitator_url}/verify")
      .to_return(status: 200, body: @expected_response_body.to_json)
    
    # Should not raise an error
    response = @client.verify_payment(string_payload, string_requirements)
    assert response.is_a?(Hash)
  end

  # Live API test - only runs when LIVE_API=true is set
  # Run with: LIVE_API=true rails test test/facilitator_client_test.rb
  test "verify_payment with real API call" do
    skip "Skipping live API test - set LIVE_API=true to run" unless ENV['LIVE_API']
    
    VCR.turned_off do
      WebMock.allow_net_connect!
      
      begin
        # Enable Rails logging to console for debugging
        old_logger = Rails.logger
        Rails.logger = Logger.new(STDOUT)
        Rails.logger.level = Logger::INFO
        
        puts "\n=== Making API Request ==="
        puts "URL: #{X402Payments.configuration.facilitator_url}/verify"
        puts "Full X402Payments Request:"
        puts JSON.pretty_generate(@payload)
        
        response = @client.verify_payment(@payload, @payment_requirements)
        
        # Assert the response structure
        assert response.is_a?(Hash)
        assert_includes response.keys, "payer"
        
        # Check for success indicators
        assert(response["isValid"] || response["success"], "Payment should be valid")
        
        # Log the response for inspection
        puts "\n=== Live API Response (SUCCESS) ==="
        puts JSON.pretty_generate(response)
      rescue X402Payments::InvalidPaymentError => e
        puts "\n=== API REJECTED PAYMENT ==="
        puts "Error: #{e.message}"
        puts "\nThis is expected with dummy test data."
        puts "The facilitator returned an error because the signature is invalid."
        puts "\nTo successfully test, you need:"
        puts "1. A real authorization from a test wallet"
        puts "2. A valid cryptographic signature"
        puts "3. Current timestamps for validAfter/validBefore"
        puts "\nCheck the logs above for the actual API response."
        raise e
      rescue X402Payments::FacilitatorError => e
        puts "\n=== FACILITATOR ERROR ==="
        puts "Error: #{e.message}"
        puts "\nA 500 error means the facilitator API had a server error."
        puts "Check the logs above for the response body from the API."
        puts "Common causes:"
        puts "- Malformed request data"
        puts "- Server-side validation error"
        puts "- API endpoint issue"
        raise e
      ensure
        Rails.logger = old_logger if old_logger
        WebMock.disable_net_connect!(allow_localhost: true)
      end
    end
  end
end