require "test_helper"

class RequirementsResponseTest < ActiveSupport::TestCase
  def setup
    @options = {
      amount: 1500,
      resource: "https://example.com/protected_resource",
      description: "Access to protected resource",
    }
  end

  test "generates payment required response with specified parameters" do
    
    response = Instapay::ResponseGenerators::RequirementsResponse.generate(@options)

    assert_equal 2, response[:x402Version]
    assert_equal "Payment required to access this resource", response[:error]
    assert_equal @options[:resource], response[:resource][:url]
    assert_equal @options[:description], response[:resource][:description]
    assert_equal "application/json", response[:resource][:mimeType]
    assert response[:accepts].is_a?(Array)
    assert_not_empty response[:accepts]
    #test asserts array contains a base64 encoded string
    response[:accepts].each do |accept_entry|
      decoded = Base64.decode64(accept_entry)
      assert decoded.is_a?(String)
      parsed = JSON.parse(decoded) rescue nil
      assert parsed.is_a?(Hash), "Decoded accepts entry should be a Hash"
      ["scheme", "network", "amount", "asset", "pay_to", "max_timeout_seconds", "extra"].each do |key|
        assert parsed.key?(key), "Accepts entry should have a '#{key}' key"
      end

    end
  end

  #test the response[:accepts] array contains the correct payment options based on different input scenarios
  test "accepts array includes custom token details when custom tokens are configured" do
    @options.merge!({
      chain: "base",
      currency: "ETH",
      wallet_address: "0xMerchantWalletAddress"
    })
    
    Instapay.configuration.custom_tokens = {
      "base:eth" => {
        symbol: "ETH",
        address: "0xCustomETHAddress",
        decimals: 6,
        name: "Ethereum", 
        version: "2"
      }
    }

    response = Instapay::ResponseGenerators::RequirementsResponse.generate(@options)

    response[:accepts].each_with_index do |accept_entry, index|
      decoded = Base64.decode64(accept_entry)
      parsed = JSON.parse(decoded)
      expected = Instapay.configuration.custom_tokens.values[index]

      assert_equal expected[:address], parsed["asset"]
    end
  end

end