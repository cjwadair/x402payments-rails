require "test_helper"

class AcceptedPaymentsBuilderTest < ActiveSupport::TestCase
  def setup
    @builder = X402Payments::ClientMessaging::AcceptedPaymentsBuilder.new
  end

  test "builds accepted payments array from options" do
    options = {
      amount: 1.50,
      accepts: [ { chain: "base-sepolia", currency: "USDC" } ]
    }

    result = @builder.build(options)

    assert result.is_a?(Array)
    assert_not_empty result

    result.each do |payment|
      assert_equal "exact", payment[:scheme]
      assert payment[:network]
      assert payment[:amount]
      assert payment[:asset]
    end
  end

  test "builds payments with default configuration when no accepts specified" do
    options = { amount: 1.00 }

    result = @builder.build(options)

    assert result.is_a?(Array)
    assert_not_empty result
  end

  test "class method delegates to instance method" do
    options = {
      amount: 2.50,
      accepts: [ { chain: "base-sepolia", currency: "USDC" } ]
    }

    result = X402Payments::ClientMessaging::AcceptedPaymentsBuilder.build(options)

    assert result.is_a?(Array)
    assert_not_empty result
  end

  test "passes currency option to resolver" do
    options = {
      amount: 1.00,
      accepts: [ { chain: "base", currency: "USDC" } ]
    }

    result = @builder.build(options)

    assert result.is_a?(Array)
    result.each do |payment|
      assert_equal "USD Coin", payment[:extra][:name]
    end
  end

  test "builds solana payment with feePayer when chain is specified via accepts array" do
    # Reproduces the case where chain: is not a top-level option but is inside accepts —
    # options[:chain] is nil while the resolved payment[:chain] is "solana".
    options = {
      amount: 1.0,
      accepts: [ { chain: "solana", currency: "USDC", wallet_address: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5" } ]
    }

    result = @builder.build(options)

    assert_equal 1, result.size
    payment = result.first
    assert_equal "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", payment[:network]
    assert payment[:extra][:feePayer], "feePayer should be present for Solana payments"
    assert_nil payment[:extra][:name], "name should not be set for Solana payments"
    assert_nil payment[:extra][:version], "version should not be set for Solana payments"
  end

  test "resolves multiple payment options when accepts is array" do
    options = {
      amount: 1.00,
      accepts: [
        { chain: "base", currency: "USDC" },
        { chain: "avalanche", currency: "USDC" }
      ]
    }

    result = @builder.build(options)

    # Should have multiple payment options
    assert result.is_a?(Array)
    assert_equal 2, result.size
  end
end
