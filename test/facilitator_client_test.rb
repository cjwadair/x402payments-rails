require "test_helper"

class FacilitatorClientTest < ActiveSupport::TestCase
  def setup
    @client = Instapay::FacilitatorClient.new

    @payload = {
      authorization:{
        from:"0x07B88Fa6bAA91384D07Ae419a08FdeC7e8908D2e",
        to:"0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
        value:"1000",
        validAfter:"1769958357",
        validBefore:"1769959257",
        nonce:"0x34567890123456..."
      },			
      signature:"0x1234567890abcdef..."	
    }

    @payment_requirements = {
      scheme: "exact", 
      network: "eip155:84532", 
      amount:"1000", 
      asset:"0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      payTo:"0x0613dA3bd559D9ECc5A662fB517Ff979CDE3E78D",
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
    stub_request(:get, "#{Instapay.configuration.facilitator_url}/supported")
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

  test "handles 500 series errors correctly" do
    stub_request(:get, "#{Instapay.configuration.facilitator_url}/supported")
      .to_return(status: 500)
    
    error = assert_raises Instapay::FacilitatorError do
      @client.supported_networks
    end
    
    assert_match(/Facilitator error \(supported\): 500/, error.message)
  end

  test "400 response raises expected error correctly" do
    stub_request(:get, "#{Instapay.configuration.facilitator_url}/supported")
      .to_return(status: 400, body: { error: "Bad Request" }.to_json)

    error = assert_raises Instapay::InvalidPaymentError do
      @client.supported_networks
    end
    
    assert_match(/Invalid payment: Bad Request/, error.message)
  end

  test 'handles unexpected response codes correctly' do
    stub_request(:get, "#{Instapay.configuration.facilitator_url}/supported")
      .to_return(status: 302)
    
    error = assert_raises Instapay::FacilitatorError do
      @client.supported_networks
    end
    
    assert_match(/Unexpected response \(supported\): 302/, error.message)
  end

  test "handles invalid JSON response correctly" do
    stub_request(:get, "#{Instapay.configuration.facilitator_url}/supported")
      .to_return(status: 200, body: "Invalid JSON") 
    
    error = assert_raises Instapay::FacilitatorError do
      @client.supported_networks
    end
    
    assert_match(/Failed to parse facilitator response/, error.message)
  end

  test "builds payment verification request and receives valid response" do
    VCR.turned_off do
      stub_request(:post, "#{Instapay.configuration.facilitator_url}/verify")
        .to_return(status: 200, body: @expected_response_body.to_json)
        
      response = @client.verify_payment(@payload, @payment_requirements)
      assert response.is_a?(Hash)
      assert_equal response.keys.sort, ["success", "transaction", "network", "payer"].sort
    end
  end
  
  test "builds payment request and receives valid response when submitting payment" do
    VCR.turned_off do
      stub_request(:post, "#{Instapay.configuration.facilitator_url}/settle")
        .to_return(status: 200, body: @expected_response_body.to_json)
        
      response = @client.settle_payment(@payload, @payment_requirements)
      assert response.is_a?(Hash)
      assert_equal response["response"], "valid JSON"
    end
  end

  test "sends payment processing request and receives valid response" do
    skip "temporarily disabled"
    payment_processing_options = {
      scheme: "exact",
      network: "base-sepolia",
      amount: 0.01,
      asset: "USDC",
      pay_to: "0xFacilitatorAddress",
      max_timeout_seconds: 300
    }

    VCR.use_cassette("facilitator_payment_processing") do
      response = @client.send_payment_processing_request(payment_processing_options)

      assert response.is_a?(Hash)
      assert response[:status] == "success"
      assert response[:paymentDetails].is_a?(Hash)
      assert response[:paymentDetails][:transactionHash].present?
    end
  end
end