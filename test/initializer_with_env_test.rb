require "test_helper"

class InitializerWithEnvTest < ActiveSupport::TestCase
  # Note: This test demonstrates how you would test different ENV configurations
  # However, since the initializer runs when Rails loads (before tests run),
  # you can't actually change ENV vars and re-run the initializer in the same process.
  # 
  # To properly test different ENV configurations, you would need to:
  # 1. Set ENV vars before running tests (e.g., in CI or shell)
  # 2. Use a separate test runner for each configuration
  # 3. Or create a helper that reloads the configuration

  test "configuration can be reset and reconfigured" do
    # Save original config
    original_wallet = Instapay.configuration.wallet_address
    
    # Reset and reconfigure
    Instapay.reset_configuration!
    
    Instapay.configure do |config|
      config.wallet_address = "0xNewTestWallet"
      config.facilitator_url = "https://test.facilitator.com"
      config.chain = "polygon-amoy"
      config.currency = "MATIC"
      config.optimistic = true
      
      config.accept(chain: "polygon-amoy", currency: "MATIC")
    end
    
    # Verify the new configuration
    config = Instapay.configuration
    assert_equal "0xNewTestWallet", config.wallet_address
    assert_equal "https://test.facilitator.com", config.facilitator_url
    assert_equal "polygon-amoy", config.chain
    assert_equal "MATIC", config.currency
    assert_equal true, config.optimistic
    
    # Restore original config for other tests
    # (In practice, you'd use setup/teardown or fixtures for this)
    Instapay.reset_configuration!
    load File.expand_path("dummy/config/initializers/instapay.rb", __dir__)
  end
end
