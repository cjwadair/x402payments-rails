# frozen_string_literal: true

module X402Payments
  class Configuration
    attr_accessor :wallet_address, :facilitator_url, :chain, :currency, :optimistic, :fee_payer, :custom_tokens
    attr_reader :custom_chains, :accepted_payments

    def initialize
      @wallet_address = ENV.fetch("X402_WALLET_ADDRESS", nil)
      @facilitator_url = ENV.fetch("X402_FACILITATOR_URL", "https://www.x402.org/facilitator")
      @chain = ENV.fetch("X402_CHAIN", "base-sepolia")
      @currency = ENV.fetch("X402_CURRENCY", "USDC")
      @optimistic = ENV.fetch("X402_OPTIMISTIC", "false") == "true"
      # TBD -- do we need this?
      @fee_payer = ENV.fetch("X402_FEE_PAYER", nil)
      @custom_chains = {}
      @custom_tokens = {}
      @accepted_payments = []
    end

    # TODO -- review other validations to cover
    def validate!
      raise ConfigurationError.new("wallet_address is required") if @wallet_address.nil? || @wallet_address.strip.empty?
      raise ConfigurationError.new("facilitator URL is required") if @facilitator_url.nil? || @facilitator_url.strip.empty?
      raise ConfigurationError.new("chain is required") if @chain.nil? || @chain.strip.empty?
    end

    def default_accepted_payments
      if @accepted_payments.empty?
        [ {
          chain: @chain,
          currency: @currency,
          wallet_address: @wallet_address
        } ]
      else
        @accepted_payments
      end
    end

    def accept(chain:, currency: nil, wallet_address: nil)
      @accepted_payments << {
        chain: chain,
        currency: currency || @currency,
        wallet_address: wallet_address || @wallet_address
      }
    end

    def register_chain(name:, chain_id:, standard:)
      unless standard == "eip155"
        raise ConfigurationError, "Only eip155 (EVM) chains are supported for custom registration"
      end

      @custom_chains[name] = {
        name: name,
        chain_id: chain_id,
        standard: standard
      }
    end

    def register_token(chain:, symbol:, address:, decimals:, name:, version: nil)
      key = "#{chain}:#{symbol}".downcase
      @custom_tokens[key] = {
        chain: chain,
        symbol: symbol,
        address: address,
        decimals: decimals,
        name: name,
        version: version
      }
    end

    def token_config(chain, symbol)
      key = "#{chain}:#{symbol}".downcase
      @custom_tokens[key]
    end

    def chain_config(name)
      @custom_chains[name]
    end
  end

  class ConfigurationError < StandardError; end
end
