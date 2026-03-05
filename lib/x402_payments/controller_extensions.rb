module X402Payments
  module ControllerExtensions
    extend ActiveSupport::Concern

    included do
      after_action :settle_deferred_payment
    end

    def require_x402_payment(options = {})
      payment_header = request.headers['PAYMENT-SIGNATURE']
      required_payment = generate_required_payment(options)
      
      if payment_header.blank?
        render_402_response(required_payment)      
      else
        # process_payment(payment_header, required_payment)

        @verified_payment = verify_payment(payment_header, required_payment)

        unless @verified_payment
          return render_402_response(required_payment)
        end
        
        unless X402Payments.configuration.optimistic
          settlement_response = settle_payment(@verified_payment)

          unless settlement_response && settlement_response["success"]
            return render_402_response(required_payment)
          end
        end
      end
    end

    private

    #note -- does not block payment if the settlement ultimately fails -- this is a best effort attempt to settle after verification, but does not impact access to the resource.
    def settle_deferred_payment
      if X402Payments.configuration.optimistic && @verified_payment.is_a?(Hash)
        settlement_response = settle_payment(@verified_payment)
      end
    end

    def render_402_response(required_payment)
      response.headers['PAYMENT-REQUIRED'] = Base64.strict_encode64(required_payment.to_json)
      render json: {error: "Payment required"}, status: :payment_required
    end

    def generate_required_payment(options)
      # Basic validation: ensure required parameters are present
      raise ArgumentError.new("amount is required") unless options[:amount].present?

      updated_options = options.merge({
        resource: request.original_url,
        description: "Payment required to access #{request.path}",
      })

      puts "Generating payment required response with options: #{updated_options.inspect}"
      
      begin
        X402Payments::ClientMessaging::PaymentRequiredResponse.generate(updated_options)
      rescue X402Payments::ClientMessaging::InvalidPaymentOptionsError => e
        # Re-raise as ArgumentError so it's clear to the developer what went wrong
        raise ArgumentError.new("Invalid payment options: #{e.message}")
      end
    end

    # def process_payment(payment_header, required_payment)
      
    #   verified_payment = verify_payment(payment_header, required_payment)

    #   unless verified_payment
    #     return render_402_response(required_payment)
    #   end
      
    #   unless X402Payments.configuration.optimistic
    #     settlement_response = settle_payment(verified_payment)

    #     unless settlement_response && settlement_response["success"]
    #       return render_402_response(required_payment)
    #     end
    #   end
    # end

    def verify_payment(payment_header, required_payment)
      # payment header is base64 encode signed authorization payload
      # options is a hash including an amount and other optional values

      # decode payment header received from client
      payment_payload = decode_header(payment_header)
      
      # Build and validate settlement request object
      # This finds a matching accept and raises InvalidSettlementRequestError if:
      # - no matching accept is found
      # - data is internally inconsistent
      begin
        settlement_request = X402Payments::FacilitatorMessaging::SettlementRequest.new(payment_payload, required_payment[:accepts]).generate
      rescue X402Payments::FacilitatorMessaging::InvalidSettlementRequestError => e
        # Expected validation error - normal business flow
        required_payment.merge!(error: e.message)
        Rails.logger.warn "Payment validation failed: #{e.message}"
        return nil
      rescue StandardError => e
        # Unexpected error - potential bug
        required_payment.merge!(error: "Payment processing error")
        Rails.logger.error "Unexpected error during payment validation: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        return nil
      end

      # Verify payment with facilitator (external verification)
      begin
        verify_result = X402Payments::FacilitatorClient.new.verify_payment(settlement_request[:paymentPayload], settlement_request[:paymentRequirements])
      rescue X402Payments::InvalidPaymentError => e
        ::Rails.logger.error "Invalid payment: #{e.message}"
        return nil
      rescue X402Payments::FacilitatorError => e
        ::Rails.logger.error "Facilitator error: #{e.message}"      
        return nil
      rescue => e
        ::Rails.logger.error "Unexpected error during payment verification: #{e.message}"
        return nil      
      end

      settlement_request
    end

    def settle_payment(settlement_request)
      begin
        settlement_response = X402Payments::FacilitatorClient.new.settle_payment(settlement_request[:paymentPayload], settlement_request[:paymentRequirements])

        # step5 - handle settlement response
        if settlement_response["success"]
          #payment settled successfully -- allow access to resource
          ::Rails.logger.info "Payment settled successfully: #{settlement_response.inspect}"
          
          #add the PAYMENT-RESPONSE header with settlement details for client reference
          response.headers['PAYMENT-RESPONSE'] = Base64.strict_encode64(settlement_response.to_json)
        end

        settlement_response
      rescue X402Payments::FacilitatorError => e
        ::Rails.logger.error "Facilitator error during settlement: #{e.message}"
        nil
      rescue StandardError => e
        ::Rails.logger.error "Unexpected error during payment settlement: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        nil
      end
    end

    def decode_header(payment_header)
      begin
        decoded = Base64.decode64(payment_header)
        JSON.parse(decoded, symbolize_names: true)
      rescue => e
        # Sanitize the error message to remove invalid UTF-8 that could cause issues
        safe_message = e.message.encode('UTF-8', invalid: :replace, undef: :replace)
        raise RuntimeError, "Invalid payment signature header: #{safe_message}"
      end
    end

  end
end