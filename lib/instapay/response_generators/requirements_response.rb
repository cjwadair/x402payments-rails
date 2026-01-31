module Instapay
  module ResponseGenerators
    class RequirementsResponse
      def self.generate(options = {})

        #step 1 -- build_accepted_payments_object
        accepted_payments = build_accepted_payments_object(options)

        #step 2 -- format the response object
        requirements_response_object = build_response_object(accepts: accepted_payments, resource_url: options[:resource], description: options[:description])

        puts "Requirements response object built: #{requirements_response_object.inspect}"  
        requirements_response_object
      end

      private 

      def self.build_accepted_payments_object(options)
        #step1 -- generate array of accepted payment options based on the args provided and users config settings for the payment options they want to accept
        accepted_payments = resolve_accepted_payments(accepts: options[:accepts], chain: options[:chain], currency: options[:currency])

        # step2 -- format each accepted payment option to meet x402 v2 spec requirements
        formatted_accepts_object = accepted_payments.map do |payment|
          build_formatted_accepts_object(payment, options)
        end

        formatted_accepts_object
      end

      def self.build_formatted_accepts_object(payment, options) 
        puts "Building formatted accepts object for payment: #{payment.inspect} with options: #{options.inspect}"
        #1 - token_config
        token_config = token_config_for(payment)
        puts "Token config found: #{token_config.inspect}"
        #2 - asset_address
        asset_address = asset_address_for(payment)
        puts "Asset address found: #{asset_address.inspect}"
        #3 - atomic_amount
        atomic_amount = convert_to_atomic_units(options[:amount], token_config[:decimals])
        puts "Atomic amount calculated: #{atomic_amount.inspect}"
        #4 - extra_data object
        extra_data = build_extra_data_object(options, token_config)
        puts "Extra data built: #{extra_data.inspect}"
        #5 - formatted network(chain)
        formatted_network = format_network(payment[:chain])
        puts "Formatted network: #{formatted_network.inspect}"
        #6 - wallet address after checking for default merchant wallet address if not provided in options
        wallet_address = options[:wallet_address] || payment[:wallet_address] || Instapay.configuration.wallet_address
        puts "Wallet address to use: #{wallet_address.inspect}"

        #TODO
        #confirm resource, description, and mimeType not required in the accepts object per x402 v2 spec
        response = {
          scheme: "exact",
          network: formatted_network,
          amount: atomic_amount.to_s,
          asset: asset_address,
          pay_to: wallet_address,
          max_timeout_seconds: 600,
          extra: extra_data
        }

        puts "formatted accepts object built: #{response.inspect}"

        Base64.strict_encode64(response.to_json)
      end

      def self.build_response_object(accepts:, resource_url:, description:)
        #TODO -- ADD ERROR HANDLING FOR MISSING PARAMS?
        # x402 response object to return
        {
          x402Version: 2,
          error: "Payment required to access this resource",
          resource: {
            url: resource_url,
            description: description || "Payment required to access #{resource_url}",
            mimeType: "application/json"
          },
          accepts: accepts
        } 
      end

      def self.resolve_accepted_payments(accepts:, chain:, currency:)
        #look up which payment options to accept based on the args provided and user config settings
        
        if accepts.present?
          #if requests specififies an accepts object, use that
          accepts.map do |acc|
            {
              chain: acc[:chain],
              currency: acc[:currency] || Instapay.configuration.currency || "USDC",
              wallet_address: acc[:wallet_address]
            }
          end
        elsif chain.present?
          #if only chain is specified, use that with default currency and no wallet address
          [{
            chain: chain, 
            currency: currency || Instapay.configuration.currency || "USDC", 
            wallet_address: nil
          }]
        else
          #otherwise use the configured accepted payments from Instapay configuration
          Instapay.configuration.default_accepted_payments
        end
      end

      def self.token_config_for(payment)
        #look up token config based on payment currency and chain
        currency ||= payment[:currency] || Instapay.configuration.currency
        chain_name = payment[:chain]
        custom = Instapay.configuration.token_config(chain_name, currency)

        if custom
          custom
        elsif currency.upcase == "USDC" && CURRENCY_BY_CHAIN[chain_name]
          CURRENCY_BY_CHAIN[chain_name]
        else
          raise Instapay::ConfigurationError, "Unknown token #{currency} for chain #{chain_name}. Register with config.register_token()"
        end
      end

      def self.asset_address_for(payment)
        currency ||= payment[:currency] || Instapay.configuration.currency
        chain_name = payment[:chain]

        custom = Instapay.configuration.token_config(chain_name, currency)
        return custom[:address] if custom

        if currency.upcase == "USDC"
          #TODO -- determine where to save the built in chain and token data
          builtin = CHAINS[chain_name]
          return builtin[:usdc_address] if builtin && builtin[:usdc_address]
        end

        raise Instapay::ConfigurationError, "Unknown token #{currency} for chain #{chain_name}. Register with config.register_token()"
      end

      def self.convert_to_atomic_units(amount, decimals)
        #convert amount to atomic units based on token decimals
        (amount.to_f * (10 ** decimals)).to_i
      end

      def self.build_extra_data_object(options, token_config)
        extra_data = {} 
        if Instapay.solana_chain?(options[:chain])
          extra_data[:feePayer] = options[:fee_payer] || Instapay.fee_payer_for(options[:chain])
        else
          extra_data[:name] = token_config[:name]
          extra_data[:version] = token_config[:version]
        end
        extra_data
      end

      def self.format_network(chain)
        #convert chain name to CAIP-2 format
        caip2 = Instapay::CAIP2_MAPPING[chain]
        raise Instapay::ConfigurationError, "Unknown chain #{chain}. Register with config.register_chain()" unless caip2
        caip2
      end

      def self.set_fee_payer(fee_payer, chain)
        
      end


    end
  end
end