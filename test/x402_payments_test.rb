require "test_helper"

class X402PaymentsTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert_equal X402Payments::VERSION, "0.1.0"
  end

  test "gemspec version matches module version" do
    gemspec_path = File.expand_path("../x402payments-rails.gemspec", __dir__)
    gemspec = Gem::Specification.load(gemspec_path)

    assert_equal X402Payments::VERSION, gemspec.version.to_s
  end

  test "version file sets VERSION constant" do
    version_file = File.expand_path("../lib/x402_payments/version.rb", __dir__)

    silence_warnings do
      load version_file
    end

    assert_equal "0.1.0", X402Payments::VERSION
  end

  test "solana_chain? returns true for solana chain names and caip2 values" do
    assert X402Payments.solana_chain?("solana")
    assert X402Payments.solana_chain?("solana-devnet")
    assert X402Payments.solana_chain?("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  end

  test "evm_chain? returns false for solana caip2 and true for eip155" do
    assert_equal false, X402Payments.evm_chain?("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
    assert X402Payments.evm_chain?("eip155:84532")
  end

  test "solana_chain? returns false for nil" do
    assert_equal false, X402Payments.solana_chain?(nil)
  end
end