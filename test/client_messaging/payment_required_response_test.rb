require "test_helper"

class PaymentRequiredResponseTest < ActiveSupport::TestCase
  def setup
    @options = {
      amount: 0.01,
      resource: "https://example.com/protected_resource",
      description: "Access to protected resource",
    }
  end

  test "generates payment required response with correct structure" do
    response = Instapay::ClientMessaging::PaymentRequiredResponse.generate(@options)

    assert_equal 2, response[:x402Version]
    assert_equal "Payment required to access this resource", response[:error]
    assert_equal @options[:resource], response[:resource][:url]
    assert_equal @options[:description], response[:resource][:description]
    assert_equal "application/json", response[:resource][:mimeType]
    assert response[:accepts].is_a?(Array)
    assert_not_empty response[:accepts]
  end

  test "uses default description when not provided" do
    @options.delete(:description)
    
    response = Instapay::ClientMessaging::PaymentRequiredResponse.generate(@options)
    
    assert_equal "Payment required to access #{@options[:resource]}", response[:resource][:description]
  end

  test "class method delegates to instance method" do
    response = Instapay::ClientMessaging::PaymentRequiredResponse.generate(@options)
    
    assert_not_nil response
    assert response[:x402Version]
  end

  test "build_response_object is publicly accessible" do
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new
    accepts = ["base64encoded1"]
    
    response = instance.build_response_object(
      accepts: accepts,
      resource_url: "https://example.com/test",
      description: "Test description"
    )
    
    assert_equal 2, response[:x402Version]
    assert_equal accepts, response[:accepts]
  end

  test "normalizes amount by stripping symbols and whitespace" do
    options = @options.merge(amount: " $1,234.56 ")
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new
    normalized = instance.send(:normalize_options!, options)
    
    assert_equal "1234.56", normalized[:amount]
  end

  test "normalizes chain to CAIP2 format if needed" do
    options = @options.merge(chain: "base-sepolia")
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new
    normalized = instance.send(:normalize_options!, options)
    
    assert_equal "eip155:84532", normalized[:chain]
  end

  test "normalizes currency to uppercase" do
    options = @options.merge(currency: "usdc")
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new
    normalized = instance.send(:normalize_options!, options)
    
    assert_equal "USDC", normalized[:currency]
  end

  test "validates amount is numeric and positive" do
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new

    invalid_options = @options.merge(amount: "invalid")
    assert_raises(Instapay::ClientMessaging::InvalidPaymentOptionsError) do
      instance.send(:validate_options!, invalid_options)
    end

    negative_options = @options.merge(amount: -5)
    assert_raises(Instapay::ClientMessaging::InvalidPaymentOptionsError) do
      instance.send(:validate_options!, negative_options)
    end
  end

  test "validates chain is supported" do
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new

    unsupported_options = @options.merge(chain: "unsupported_chain")
    assert_raises(Instapay::ClientMessaging::InvalidPaymentOptionsError) do
      instance.send(:validate_options!, unsupported_options)
    end
  end

  test "validates currency is a string" do
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new

    invalid_options = @options.merge(currency: 123)
    assert_raises(Instapay::ClientMessaging::InvalidPaymentOptionsError) do
      instance.send(:validate_options!, invalid_options)
    end
  end

  test "validates wallet_address format" do
    instance = Instapay::ClientMessaging::PaymentRequiredResponse.new

    invalid_options = @options.merge(wallet_address: :symbol)
    assert_raises(Instapay::ClientMessaging::InvalidPaymentOptionsError) do
      instance.send(:validate_options!, invalid_options)
    end
  end

end