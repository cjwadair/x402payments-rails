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

  test "build_response creates response object with accepts array" do
    accepts = ["base64encoded1", "base64encoded2"]
    resource_url = "https://example.com/api/content"
    description = "Premium content access"
    
    response = Instapay::ClientMessaging::PaymentRequiredResponse.build_response(
      accepts: accepts,
      resource_url: resource_url,
      description: description
    )
    
    assert_equal 2, response[:x402Version]
    assert_equal "Payment required to access this resource", response[:error]
    assert_equal resource_url, response[:resource][:url]
    assert_equal description, response[:resource][:description]
    assert_equal "application/json", response[:resource][:mimeType]
    assert_equal accepts, response[:accepts]
  end

  test "build_response uses default description when nil" do
    accepts = ["base64encoded1"]
    resource_url = "https://example.com/api/content"
    
    response = Instapay::ClientMessaging::PaymentRequiredResponse.build_response(
      accepts: accepts,
      resource_url: resource_url,
      description: nil
    )
    
    assert_equal "Payment required to access #{resource_url}", response[:resource][:description]
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

end