#frozen_string_literal: true

module Instapay
  class Configuration

    attr_accessor :wallet_address, :facilitator, :chain, :currency, :optimistic, :fee_payer
    attr_reader :custom_chains, :custom_tokens, :accepted_payments

    def initialize
      @wallet_address = ENV.fetch("X402_WALLET_ADDRESS", nil)
      @facilitator = ENV.fetch("X402_FACILITATOR_URL", "https://www.x402.org/facilitator")
      @chain = ENV.fetch("X402_CHAIN", "base-sepolia")
      @currency = ENV.fetch("X402_CURRENCY", "USDC")
      @optimistic = ENV.fetch("X402_OPTIMISTIC", "false") == "true"
      #TBD -- do we need this? 
      @fee_payer = ENV.fetch("X402_FEE_PAYER", nil)
      @custom_chains = {}
      @custom_tokens = {}
      @accepted_payments = []
    end

    #TODO -- review other validations to cover
    def validate!
      raise ConfigurationError.new("wallet_address is required") if @wallet_address.nil? || @wallet_address.strip.empty?
      raise ConfigurationError.new("facilitator URL is required") if @facilitator.nil? || @facilitator.strip.empty?
      raise ConfigurationError.new("chain is required") if @chain.nil? || @chain.strip.empty?
    end

    def default_accepted_payments
      if @accepted_payments.empty?
        [{
          chain: @chain,
          currency: @currency,
          wallet_address: @wallet_address
        }]
      else
        @accepted_payments
      end
    end

    def accept(chain:, currency: nil, wallet_address: nil)
      @accepted_payments << {
        chain: chain,
        currency: currency || @currency,
        wallet_address: wallet_address
      }
    end

    def register_chain(name:, chain_id:, standard:)
      @custom_chains[name] = {
        name: name,
        chain_id: chain_id,
        standard: standard
      }
    end

    def register_token(chain:, symbol:, address:, decimals:, name:, version: nil)
      normalized_symbol = symbol.to_s.upcase
      @custom_tokens[chain] ||= {}
      @custom_tokens[chain][normalized_symbol] = {
        chain: chain,
        symbol: normalized_symbol,
        address: address,
        decimals: decimals,
        name: name,
        version: version
      }
    end

    def token_config(chain, symbol)
      @custom_tokens.dig(chain, symbol.to_s.upcase)
    end

    def chain_config(name)
      @custom_chains[name]
    end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      #initializes the configuration object and yields it to a block for setting config options
      #triggered when user sets the initializers/instapay.rb file
      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = Configuration.new
      end

    end

    class ConfigurationError < StandardError; end

  end
end