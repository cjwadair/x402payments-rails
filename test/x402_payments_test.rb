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

  test "returns correct supported chains" do
    chains = X402Payments::Chains::CHAINS.keys + X402Payments.configuration.custom_chains.keys
    expected_chains = chains.map { |k| X402Payments.to_caip2(k) }
    assert_equal expected_chains.sort, X402Payments.supported_chains.sort
  end

  test "to_caip2 returns correct CAIP-2 values" do
    assert_equal "eip155:84532", X402Payments.to_caip2("base-sepolia")
    assert_equal "eip155:8453", X402Payments.to_caip2("base")
    assert_equal "eip155:43113", X402Payments.to_caip2("avalanche-fuji")
    assert_equal "eip155:43114", X402Payments.to_caip2("avalanche")
    assert_equal "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", X402Payments.to_caip2("solana-devnet")
    assert_equal "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", X402Payments.to_caip2("solana")
  end

  test "to_caip2 raises error for unknown chain" do
    assert_raises(X402Payments::ConfigurationError) do
      X402Payments.to_caip2("unknown-chain")
    end
  end

  test "from_caip2 returns correct network names" do
    assert_equal "base-sepolia", X402Payments.from_caip2("eip155:84532")
    assert_equal "base", X402Payments.from_caip2("eip155:8453")
    assert_equal "avalanche-fuji", X402Payments.from_caip2("eip155:43113")
    assert_equal "avalanche", X402Payments.from_caip2("eip155:43114")
    assert_equal "solana-devnet", X402Payments.from_caip2("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
    assert_equal "solana", X402Payments.from_caip2("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
  end

  test "from_caip2 returns correct network names for custom chains" do
    X402Payments.configuration.custom_chains.each do |name, config|
      caip2 = "#{config[:standard]}:#{config[:chain_id]}"
      assert_equal name, X402Payments.from_caip2(caip2)
    end
  end

  test "from_caip2 raises error for unknown CAIP-2 string" do
    assert_raises(X402Payments::ConfigurationError) do
      X402Payments.from_caip2("unknown:caip2")
    end
  end

  test "fee_payer_for returns correct fee payer for solana chains" do
    assert_equal "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5", X402Payments.fee_payer_for("solana")
    assert_equal "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5", X402Payments.fee_payer_for("solana-devnet")
  end

  test "fee_payer_for returns correct fee payer for evm chains" do
    assert_nil X402Payments.fee_payer_for("base-sepolia")
    assert_nil X402Payments.fee_payer_for("base")
    assert_nil X402Payments.fee_payer_for("avalanche-fuji")
    assert_nil X402Payments.fee_payer_for("avalanche")
  end

end
