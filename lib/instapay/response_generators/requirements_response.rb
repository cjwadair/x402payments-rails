module Instapay
  module ResponseGenerators
    class RequirementsResponse
      def self.generate(options = {})
        # {
        #   "x402Version":2,
        #   "error":"Payment required",
        #   "resource":{
        #     "url":"http://localhost:8000/forecast?location=new+york",  
        #     "description":"Get weather forecast data for any location"
        #     "mimeType":"application/json"
        #   },
        #   "accepts":[
        #     {
        #       "scheme":"exact",
        #       "network":"eip155:84532",
        #       "amount":"1000",
        #       "asset":"0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        #       "payTo":"0x0613da3bd559d9ecc5a662fb517ff979cde3e78d",
        #       "maxTimeoutSeconds":300,
        #       "extra":{
        #         "name":"USDC",
        #         "version":"2"
        #       }
        #     }
        #   ]
        # }

        #step 1 -- build and format the accepted payments object
          # a - looks up and resolves accepted payments for the current request
          # b - handles formatting of accepted payment options object
            # i - (note right now only wallet potentially changes and version strategy added, but may be able to avoid both of these)
            # ii - reformats result objects to meet x402 v2 spec requirements
        # step 2 -- formats the object generated in step 1
          # adds x402Version to the object and compacts the results object -- may be able to combine step 1 and step 2 depending on implementation
          # adds an extensions key with empty hash as value to the object

        #step 1 -- build_accepted_payments_object
        accepted_payments = build_accepted_payments_object(options)

        #step 2 -- format the response object
        #note -- can simplify this to just pass in options object to the response generator
        requirements_response_object = build_response_object(
          amount: options[:amount],
          chain: options[:chain], #use chain name and covert to CAIP-2 format in helper method
          currency: options[:currency], #currency supplied by client or USDC
          version: "2", #optional add v1 support as well...
          wallet_address: options[:wallet_address], #merchant wallet address to receive payment
          fee_payer: options[:fee_payer], #populates into extra element - fee_payer key if solana chain otherwise name and version
          accepts: accepted_payments #array of accepted payment methods with scheme, network, amount, asset, payTo, maxTimeoutSeconds, extra
        )
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
        #2 - asset_address
        asset_address = asset_address_for(payment)
        #3 - atomic_amount
        atomic_amount = convert_to_atomic_units(payment[:amount], token_config[:decimals])
        #4 - extra_data object
        extra_data = build_extra_data_object(options, token_config)
        #5 - formatted network(chain)
        formatted_network = format_network(options[:chain])
        #6 - wallet address after checking for default merchant wallet address if not provided in options
        wallet_address = options[:wallet_address] || payment[:wallet_address] || Instapay.configuration.wallet_address

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
              currency: acc[:currency] || "USDC",
              wallet_address: acc[:wallet_address]
            }
          end
        elsif chain.present?
          #if only chain is specified, use that with default currency and no wallet address
          [{
            chain: chain, 
            currency: currency || Instapay.configuration.currency, 
            wallet_address: nil
          }]
        else
          #otherwise use the configured accepted payments from Instapay configuration
          Instapay.configuration.default_accepted_payments
        end
      end

      def self.token_config_for(payment)
        #look up token config based on payment currency and chain
        symbol ||= payment[:symbol] || Instapay.configuration.currency
        chain_name = payment[:chain]

        custom = Instapay.configuration.token_config(chain_name, symbol)
        return custom[:address] if custom

        if symbol.upcase == "USDC"
          #TODO -- determine where to save the built in chain and token data
          builtin = CHAINS[chain_name]
          return builtin[:usdc_address] if builtin && builtin[:usdc_address]
        end

        raise ConfigurationError, "Unknown token #{symbol} for chain #{chain_name}. Register with config.register_token()"
      end

      def self.asset_address_for(payment)
        symbol ||= payment[:symbol] || Instapay.configuration.currency
        chain_name = payment[:chain]

        custom = Instapay.configuration.token_config(chain_name, symbol)
        return custom[:address] if custom

        if symbol.upcase == "USDC"
          #TODO -- determine where to save the built in chain and token data
          builtin = CHAINS[chain_name]
          return builtin[:usdc_address] if builtin && builtin[:usdc_address]
        end

        raise ConfigurationError, "Unknown token #{symbol} for chain #{chain_name}. Register with config.register_token()"
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
        raise ConfigurationError, "Unknown chain #{chain}. Register with config.register_chain()" unless caip2
        caip2
      end

      def self.set_fee_payer(fee_payer, chain)
        
      end


    end
  end
end