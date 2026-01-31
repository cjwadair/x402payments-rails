require "test_helper"

class AcceptedPaymentsFormatterTest < ActiveSupport::TestCase
  def setup
    @formatter = Instapay::ResponseGenerators::AcceptedPaymentsFormatter.new
  end

  test "formats payment with built-in chain and currency" do
    payment = { chain: "base-sepolia", currency: "USDC" }
    options = { amount: 1.50 }
    
    encoded = @formatter.format(payment, options)
    decoded = Base64.decode64(encoded)
    parsed = JSON.parse(decoded)
    
    assert_equal "exact", parsed["scheme"]
    assert_equal "eip155:84532", parsed["network"]
    assert_equal "1500000", parsed["amount"] # 1.50 * 10^6
    assert_equal "0x036CbD53842c5426634e7929541eC2318f3dCF7e", parsed["asset"]
    assert_equal Instapay.configuration.wallet_address, parsed["pay_to"]
    assert_equal 600, parsed["max_timeout_seconds"]
    assert parsed["extra"].is_a?(Hash)
    assert_equal "USDC", parsed["extra"]["name"]
    assert_equal "2", parsed["extra"]["version"]
  end

  test "formats payment with custom wallet address from options" do
    payment = { chain: "base-sepolia", currency: "USDC" }
    options = { amount: 0.50, wallet_address: "0xCustomWallet" }
    
    encoded = @formatter.format(payment, options)
    decoded = Base64.decode64(encoded)
    parsed = JSON.parse(decoded)
    
    assert_equal "0xCustomWallet", parsed["pay_to"]
  end

  test "formats payment with custom wallet address from payment" do
    payment = { chain: "base-sepolia", currency: "USDC", wallet_address: "0xPaymentWallet" }
    options = { amount: 0.50 }
    
    encoded = @formatter.format(payment, options)
    decoded = Base64.decode64(encoded)
    parsed = JSON.parse(decoded)
    
    assert_equal "0xPaymentWallet", parsed["pay_to"]
  end

  test "converts amount to atomic units correctly" do
    payment = { chain: "base-sepolia", currency: "USDC" }
    options = { amount: 10.123456 }
    
    encoded = @formatter.format(payment, options)
    decoded = Base64.decode64(encoded)
    parsed = JSON.parse(decoded)
    
    assert_equal "10123456", parsed["amount"] # 10.123456 * 10^6
  end

  test "formats network using CAIP2 mapping" do
    payment = { chain: "avalanche", currency: "USDC" }
    options = { amount: 1.0 }
    
    encoded = @formatter.format(payment, options)
    decoded = Base64.decode64(encoded)
    parsed = JSON.parse(decoded)
    
    assert_equal "eip155:43114", parsed["network"]
  end

  test "raises error for unknown chain in CAIP2 mapping" do
    # Register a custom token so we pass token validation, but use unknown chain for CAIP2
    Instapay.configuration.register_token(
      chain: "unknown-chain",
      symbol: "USDC",
      address: "0xTestAddress",
      decimals: 6,
      name: "Test USDC",
      version: "2"
    )
    
    payment = { chain: "unknown-chain", currency: "USDC" }
    options = { amount: 1.0 }
    
    error = assert_raises(Instapay::ConfigurationError) do
      @formatter.format(payment, options)
    end
    
    assert_includes error.message, "Unknown chain unknown-chain"
  end

  test "formats solana payment with feePayer in extra data" do
    payment = { chain: "solana-devnet", currency: "USDC" }
    options = { amount: 1.0, chain: "solana-devnet" }
    
    encoded = @formatter.format(payment, options)
    decoded = Base64.decode64(encoded)
    parsed = JSON.parse(decoded)
    
    assert parsed["extra"]["feePayer"]
    assert_nil parsed["extra"]["name"]
    assert_nil parsed["extra"]["version"]
  end

  test "uses custom token config when registered" do
    Instapay.configuration.register_token(
      chain: "base",
      symbol: "ETH",
      address: "0xCustomETHAddress",
      decimals: 18,
      name: "Ethereum",
      version: "1"
    )
    
    payment = { chain: "base", currency: "ETH" }
    options = { amount: 1.0 }
    
    encoded = @formatter.format(payment, options)
    decoded = Base64.decode64(encoded)
    parsed = JSON.parse(decoded)
    
    assert_equal "0xCustomETHAddress", parsed["asset"]
    assert_equal "1000000000000000000", parsed["amount"] # 1.0 * 10^18
    assert_equal "Ethereum", parsed["extra"]["name"]
    assert_equal "1", parsed["extra"]["version"]
  end

  test "raises error for unknown token" do
    payment = { chain: "base", currency: "UNKNOWN" }
    options = { amount: 1.0 }
    
    error = assert_raises(Instapay::ConfigurationError) do
      @formatter.format(payment, options)
    end
    
    assert_includes error.message, "Unknown token UNKNOWN for chain base"
  end
end
