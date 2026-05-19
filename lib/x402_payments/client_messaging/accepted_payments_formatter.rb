# frozen_string_literal: true

require "bigdecimal"

module X402Payments
  module ClientMessaging
    class AcceptedPaymentsFormatter
      def format(payment, options)
        
        token_config = get_token_config(payment)
        asset_address = token_config[:address]
        atomic_amount = convert_to_atomic_units(options[:amount], token_config[:decimals])
        extra_data = build_extra_data(payment, options, token_config)
        formatted_network = format_network(payment[:chain])
        wallet_address = resolve_wallet_address(payment, options)

        {
          scheme: "exact",
          network: formatted_network,
          amount: atomic_amount.to_s,
          asset: asset_address,
          payTo: wallet_address,
          maxTimeoutSeconds: X402Payments::MAX_TIMEOUT_SECONDS,
          extra: extra_data
        }
      end

      private

      def get_token_config(payment)
        currency = payment[:currency] || X402Payments.configuration.currency
        chain_name = payment[:chain]
        custom = X402Payments.configuration.token_config(chain_name, currency)

        if custom
          custom
        elsif currency.upcase == "USDC" && X402Payments::Chains::CURRENCY_BY_CHAIN[chain_name]
          builtin = X402Payments::Chains::CHAINS[chain_name]
          X402Payments::Chains::CURRENCY_BY_CHAIN[chain_name].merge(address: builtin[:usdc_address])
        else
          raise X402Payments::ConfigurationError, "Unknown token #{currency} for chain #{chain_name}. Register with config.register_token()"
        end
      end

      def convert_to_atomic_units(amount, decimals)
        (BigDecimal(amount.to_s) * 10**decimals).to_i
      end

      def build_extra_data(payment, options, token_config)
        if X402Payments.solana_chain?(payment[:chain])
          { feePayer: options[:fee_payer] || X402Payments.fee_payer_for(payment[:chain]) }
        else
          { name: token_config[:name], version: token_config[:version] }
        end
      end

      def format_network(chain)
        X402Payments.to_caip2(chain)
      rescue X402Payments::ConfigurationError
        raise X402Payments::ConfigurationError, "Unknown chain #{chain}. Register with config.register_chain()"
      end

      def resolve_wallet_address(payment, options)
        options[:wallet_address] || payment[:wallet_address] || X402Payments.configuration.wallet_address
      end
    end
  end
end
