module Instapay
  module ControllerExtensions
    extend ActiveSupport::Concern

    included do
      after_action :settle_payment_if_needed
    end

    # Optional: in a controller, call `before_action :enforce_paywall`
    # to run this hook ahead of every request.
    def enforce_paywall
      require_payment
    end

    def require_payment
      if request.headers['PAYMENT-SIGNATURE'].blank?
        render_payment_required
      end
    end

    class_methods do
      def skip_paywall_enforcement(**options)
        skip_before_action :enforce_paywall, **options
      end
    end

    private

    def settle_payment_if_needed
      settle_payment
    end

    def settle_payment
      # whatever you want the after_action to do
    end

    def render_payment_required(options = {})
      raise ArgumentError.new("amount is required") unless options[:amount].present?

      updated_options = options.merge({
        resource: request.original_url,
        description: "Payment required to access #{request.path}",
      })

      #note -- add error handling here in case of an error generating the response object
      response_object = Instapay::ResponseGenerators::RequirementsResponse.generate(updated_options)

      render json: response_object, status: :payment_required
    end

    #move to a payment required response generator class???
    # def generate_payment_required_response(amount:, chain:, currency:, version:, wallet_address:, fee_payer:, accepts:)
    #   # Implement the logic to generate the payment required response object
    #   # based on the provided parameters.
    #   response = {
    #     x402Version: version.to_i,
    #     error: "Payment required",
    #     resource: {
    #       url: request.url,
    #       description: "Access to this resource requires payment",
    #       mimeType: request.format.to_s
    #     },
    #     accepts: accepts || [
    #       {
    #         scheme: "exact",
    #         network: chain || "eip155:1", # default to Ethereum mainnet -- add converter method later
    #         amount: amount.to_s, #?convert $amount to applicable payment units for the selected currency/chain 
    #         asset: set_currency_address(chain, currency), # add helper to set the required asset address based on chain and currency
    #         payTo: wallet_address || payment[:wallet_address] || config.wallet_address, # tdb -- add handling for default merchant wallet address?
    #         maxTimeoutSeconds: 300,
    #         extra: set_extra_fields(chain, currency, fee_payer) # add helper to set extra fields based on chain and currency -- fee_payer for solana, name, version for other chains
    #       }
    #     ]
    #   }
      
    #   # Base64.strict_encode64(response.to_json)
    #   base64_encoded_response(response) #helper method to handle base64 encoding
    # end

  end
end