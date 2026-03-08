require "test_helper"

class AcceptedPaymentsResolverTest < ActiveSupport::TestCase
  def setup
    @resolver = X402Payments::ClientMessaging::AcceptedPaymentsResolver.new
  end

  test "resolves from accepts array when provided" do
    accepts = [
      { chain: "base", currency: "USDC", wallet_address: "0xWallet1" },
      { chain: "avalanche", currency: "ETH", wallet_address: "0xWallet2" }
    ]

    result = @resolver.resolve(accepts: accepts, chain: nil, currency: nil)

    assert_equal 2, result.size
    assert_equal "base", result[0][:chain]
    assert_equal "USDC", result[0][:currency]
    assert_equal "0xWallet1", result[0][:wallet_address]
    assert_equal "avalanche", result[1][:chain]
    assert_equal "ETH", result[1][:currency]
    assert_equal "0xWallet2", result[1][:wallet_address]
  end

  test "resolves from chain when accepts not provided" do
    result = @resolver.resolve(accepts: nil, chain: "base", currency: "USDC")

    assert_equal 1, result.size
    assert_equal "base", result[0][:chain]
    assert_equal "USDC", result[0][:currency]
    assert_nil result[0][:wallet_address]
  end

  test "uses default config currency when chain provided but currency not" do
    result = @resolver.resolve(accepts: nil, chain: "avalanche", currency: nil)

    assert_equal 1, result.size
    assert_equal "avalanche", result[0][:chain]
    assert_equal "USDC", result[0][:currency]
  end

  test "uses default accepted payments when neither accepts nor chain provided" do
    result = @resolver.resolve(accepts: nil, chain: nil, currency: nil)

    assert_equal 1, result.size
    assert_equal X402Payments.configuration.chain, result[0][:chain]
    assert_equal X402Payments.configuration.currency, result[0][:currency]
    assert_equal X402Payments.configuration.wallet_address, result[0][:wallet_address]
  end

  test "fills in missing currency from config in accepts array" do
    accepts = [ { chain: "base" } ]

    result = @resolver.resolve(accepts: accepts, chain: nil, currency: nil)

    assert_equal "USDC", result[0][:currency]
  end
end
