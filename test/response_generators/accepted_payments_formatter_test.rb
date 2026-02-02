require "test_helper"

class AcceptedPaymentsFormatterTest < ActiveSupport::TestCase
  def setup
    @formatter = Instapay::ClientMessaging::AcceptedPaymentsFormatter.new
  end

  test "formats payment with built-in chain and currency" do
    payment = { chain: "base-sepolia", currency: "USDC" }
    options = { amount: 1.50 }
    
    response = @formatter.format(payment, options)
    
    
    assert_equal "exact", response[:scheme]
    assert_equal "eip155:84532", response[:network]
    assert_equal "1500000", response[:amount] # 1.50 * 10^6
    assert_equal "0x036CbD53842c5426634e7929541eC2318f3dCF7e", response[:asset]
    assert_equal Instapay.configuration.wallet_address, response[:pay_to]
    assert_equal 600, response[:max_timeout_seconds]
    assert response[:extra].is_a?(Hash)
    assert_equal "USDC", response[:extra][:name]
    assert_equal "2", response[:extra][:version]
  end

  test "formats payment with custom wallet address from options" do
    payment = { chain: "base-sepolia", currency: "USDC" }
    options = { amount: 0.50, wallet_address: "0xCustomWallet" }
    
    response = @formatter.format(payment, options)
    
    assert_equal "0xCustomWallet", response[:pay_to]
  end

  test "formats payment with custom wallet address from payment" do
    payment = { chain: "base-sepolia", currency: "USDC", wallet_address: "0xPaymentWallet" }
    options = { amount: 0.50 }
    
    response = @formatter.format(payment, options)
    
    assert_equal "0xPaymentWallet", response[:pay_to]
  end

  test "converts amount to atomic units correctly" do
    payment = { chain: "base-sepolia", currency: "USDC" }
    options = { amount: 10.123456 }
    
    response = @formatter.format(payment, options)
    
    assert_equal "10123456", response[:amount] # 10.123456 * 10^6
  end

  test "formats network using CAIP2 mapping" do
    payment = { chain: "avalanche", currency: "USDC" }
    options = { amount: 1.0 }
    
    response = @formatter.format(payment, options)
    
    assert_equal "eip155:43114", response[:network]
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
    
    response = @formatter.format(payment, options)
    assert_equal "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", response[:network]
    assert_equal "1000000", response[:amount] # 1.0 * 10^6
    assert response[:extra][:feePayer]
    assert_nil response[:extra][:name]
    assert_nil response[:extra][:version]
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
    
    response = @formatter.format(payment, options)
    
    assert_equal "0xCustomETHAddress", response[:asset]
    assert_equal "1000000000000000000", response[:amount] # 1.0 * 10^18
    assert_equal "Ethereum", response[:extra][:name]
    assert_equal "1", response[:extra][:version]
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
