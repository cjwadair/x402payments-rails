require "test_helper"

class PaymentRequiredResponseTest < ActiveSupport::TestCase
  def setup
    @options = {
      amount: 1500,
      resource: "https://example.com/protected_resource",
      description: "Access to protected resource",
    }
  end

  test "generates payment required response with correct structure" do
    response = Instapay::ResponseGenerators::PaymentRequiredResponse.generate(@options)

    assert_equal 2, response[:x402Version]
    assert_equal "Payment required to access this resource", response[:error]
    assert_equal @options[:resource], response[:resource][:url]
    assert_equal @options[:description], response[:resource][:description]
    assert_equal "application/json", response[:resource][:mimeType]
    assert response[:accepts].is_a?(Array)
    assert_not_empty response[:accepts]
    
    # Verify accepts array contains base64 encoded payment options
    response[:accepts].each do |accept_entry|
      assert_nothing_raised { Base64.decode64(accept_entry) }
    end
  end

  test "uses default description when not provided" do
    @options.delete(:description)
    
    response = Instapay::ResponseGenerators::PaymentRequiredResponse.generate(@options)
    
    assert_equal "Payment required to access #{@options[:resource]}", response[:resource][:description]
  end

  test "class method delegates to instance method" do
    response = Instapay::ResponseGenerators::PaymentRequiredResponse.generate(@options)
    
    assert_not_nil response
    assert response[:x402Version]
  end

end