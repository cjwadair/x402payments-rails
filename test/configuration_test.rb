require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  test "initializes with default values" do
    config = X402Payments::Configuration.new
    assert_equal "base-sepolia", config.chain
    assert_equal "USDC", config.currency
    assert_nil config.wallet_address
    assert_empty config.accepted_payments
  end

  test "allows setting and getting configuration options" do
    config = X402Payments::Configuration.new
    config.chain = "avalanche"
    config.currency = "ETH"
    config.wallet_address = "0xMerchantWalletAddress"
    assert_equal "avalanche", config.chain
    assert_equal "ETH", config.currency
    assert_equal "0xMerchantWalletAddress", config.wallet_address
  end

  test "accepts method adds accepted payment options" do
    config = X402Payments::Configuration.new
    config.accept(chain: "solana", currency: "USDC", wallet_address: "SolanaWalletAddress")
    assert_equal 1, config.accepted_payments.size
    payment = config.accepted_payments.first
    assert_equal "solana", payment[:chain]
    assert_equal "USDC", payment[:currency]
    assert_equal "SolanaWalletAddress", payment[:wallet_address]
  end

  test "default_accepted_payments returns correct defaults" do
    config = X402Payments::Configuration.new
    defaults = config.default_accepted_payments
    assert_equal 1, defaults.size
    payment = defaults.first
    assert_equal config.chain, payment[:chain]
    assert_equal config.currency, payment[:currency]
    assert_equal config.wallet_address, payment[:wallet_address]
  end

  test "registers and retrieves custom token configurations" do
    X402Payments.configure do |config|
      config.register_token(
        chain: "base",
        symbol: "ETH",
        address: "0xCustomETHAddress",
        decimals: 6,
        name: "Ethereum",
        version: "2"
      )
    end

    token_config = X402Payments.configuration.token_config("base", "ETH")
    assert_not_nil token_config
    assert_equal "0xCustomETHAddress", token_config[:address]
    assert_equal 6, token_config[:decimals]
    assert_equal "Ethereum", token_config[:name]
    assert_equal "2", token_config[:version]
  end

  test "registers and retrieves custom chain configurations" do
    X402Payments.configure do |config|
      config.register_chain(
        name: "custom-chain",
        chain_id: 12345,
        standard: "eip155"
      )
    end

    chain_config = X402Payments.configuration.chain_config("custom-chain")
    assert_not_nil chain_config
    assert_equal 12345, chain_config[:chain_id]
    assert_equal "eip155", chain_config[:standard]
  end

  test "raises error registering unsupported chain standard" do
    X402Payments.configure do |config|
      assert_raises(X402Payments::ConfigurationError) do
        config.register_chain(
          name: "unsupported-chain",
          chain_id: 99999,
          standard: "unsupported-standard"
        )
      end
    end
  end

  test "multiple accepted payments are stored correctly" do
    config = X402Payments::Configuration.new
    config.accept(chain: "base-sepolia", currency: "USDC")
    config.accept(chain: "polygon", currency: "MATIC", wallet_address: "PolygonWalletAddress")
    assert_equal 2, config.accepted_payments.size

    first_payment = config.accepted_payments[0]
    assert_equal "base-sepolia", first_payment[:chain]
    assert_equal "USDC", first_payment[:currency]
    assert_nil first_payment[:wallet_address]

    second_payment = config.accepted_payments[1]
    assert_equal "polygon", second_payment[:chain]
    assert_equal "MATIC", second_payment[:currency]
    assert_equal "PolygonWalletAddress", second_payment[:wallet_address]
  end

  test "token_config returns nil for unregistered tokens" do
    token_config = X402Payments.configuration.token_config("nonexistent-chain", "NONEXISTENT")
    assert_nil token_config
  end

  test "chain_config returns nil for unregistered chains" do
    chain_config = X402Payments.configuration.chain_config("nonexistent-chain")
    assert_nil chain_config
  end

  test "default_accepted_payments uses configured accepted payments when present" do
    config = X402Payments::Configuration.new
    config.chain = "base-sepolia"
    config.currency = "USDC"
    config.wallet_address = "0xMerchantWalletAddress"

    config.accept(chain: "polygon", currency: "MATIC", wallet_address: "PolygonWalletAddress")

    defaults = config.default_accepted_payments
    assert_equal 1, defaults.size
    payment = defaults.first
    assert_equal "polygon", payment[:chain]
    assert_equal "MATIC", payment[:currency]
    assert_equal "PolygonWalletAddress", payment[:wallet_address]
  end
end
