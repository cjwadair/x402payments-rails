require "test_helper"

class InitializerTest < ActiveSupport::TestCase
  test "dummy app initializer sets configuration values correctly" do
    config = X402Payments.configuration

    # Test that configuration values from the initializer are set
    assert_equal "0x0613da3bd559d9ecc5a662fb517ff979cde3e78d", config.wallet_address
    assert_equal "https://www.x402.org/facilitator", config.facilitator_url
    assert_equal "base-sepolia", config.chain
    assert_equal "USDC", config.currency
    assert_equal false, config.optimistic

    # Test that accepted payments were configured
    assert_equal 1, config.accepted_payments.size
    payment = config.accepted_payments.first
    assert_equal "base-sepolia", payment[:chain]
    assert_equal "USDC", payment[:currency]
  end

  test "initializer respects environment variables when set" do
    # This test verifies that the initializer properly uses ENV vars
    # The actual env vars would need to be set before Rails loads
    # This test just validates the current state matches expected defaults

    config = X402Payments.configuration

    # Since no custom ENV vars are set in test, these should be the defaults
    assert_equal ENV.fetch("X402_WALLET_ADDRESS", "0x0613da3bd559d9ecc5a662fb517ff979cde3e78d"),
                 config.wallet_address
    assert_equal ENV.fetch("X402_FACILITATOR_URL", "https://www.x402.org/facilitator"),
                 config.facilitator_url
    assert_equal ENV.fetch("X402_CHAIN", "base-sepolia"),
                 config.chain
    assert_equal ENV.fetch("X402_CURRENCY", "USDC"),
                 config.currency
    assert_equal (ENV.fetch("X402_OPTIMISTIC", "false") == "true"),
                 config.optimistic
  end
end
