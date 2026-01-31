module Instapay
  module ResponseGenerators
    class AcceptedPaymentsFormatter
      def format(payment, options)
        token_config = get_token_config(payment)
        asset_address = get_asset_address(payment)
        atomic_amount = convert_to_atomic_units(options[:amount], token_config[:decimals])
        extra_data = build_extra_data(options, token_config)
        formatted_network = format_network(payment[:chain])
        wallet_address = resolve_wallet_address(payment, options)

        response = {
          scheme: "exact",
          network: formatted_network,
          amount: atomic_amount.to_s,
          asset: asset_address,
          pay_to: wallet_address,
          max_timeout_seconds: 600,
          extra: extra_data
        }

        Base64.strict_encode64(response.to_json)
      end

      private

      def get_token_config(payment)
        currency = payment[:currency] || Instapay.configuration.currency
        chain_name = payment[:chain]
        custom = Instapay.configuration.token_config(chain_name, currency)

        if custom
          custom
        elsif currency.upcase == "USDC" && Instapay::CURRENCY_BY_CHAIN[chain_name]
          Instapay::CURRENCY_BY_CHAIN[chain_name]
        else
          raise Instapay::ConfigurationError, "Unknown token #{currency} for chain #{chain_name}. Register with config.register_token()"
        end
      end

      def get_asset_address(payment)
        currency = payment[:currency] || Instapay.configuration.currency
        chain_name = payment[:chain]

        custom = Instapay.configuration.token_config(chain_name, currency)
        return custom[:address] if custom

        if currency.upcase == "USDC"
          builtin = Instapay::CHAINS[chain_name]
          return builtin[:usdc_address] if builtin && builtin[:usdc_address]
        end

        raise Instapay::ConfigurationError, "Unknown token #{currency} for chain #{chain_name}. Register with config.register_token()"
      end

      def convert_to_atomic_units(amount, decimals)
        (amount.to_f * (10 ** decimals)).to_i
      end

      def build_extra_data(options, token_config)
        extra_data = {}
        if Instapay.solana_chain?(options[:chain])
          extra_data[:feePayer] = options[:fee_payer] || Instapay.fee_payer_for(options[:chain])
        else
          extra_data[:name] = token_config[:name]
          extra_data[:version] = token_config[:version]
        end
        extra_data
      end

      def format_network(chain)
        caip2 = Instapay::CAIP2_MAPPING[chain]
        raise Instapay::ConfigurationError, "Unknown chain #{chain}. Register with config.register_chain()" unless caip2
        caip2
      end

      def resolve_wallet_address(payment, options)
        options[:wallet_address] || payment[:wallet_address] || Instapay.configuration.wallet_address
      end
    end
  end
end
