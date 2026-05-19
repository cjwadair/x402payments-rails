# frozen_string_literal: true

module X402Payments
  module ControllerExtensions
    extend ActiveSupport::Concern

    included do
      after_action :settle_deferred_payment
    end

    def require_x402_payment(options = {})
      payment_header = request.headers["PAYMENT-SIGNATURE"]
      required_payment = generate_required_payment(options)

      if payment_header.blank?
        render_402_response(required_payment)
      else
        @verified_payment = verify_payment(payment_header, required_payment)

        unless @verified_payment
          return render_402_response(required_payment)
        end

        unless X402Payments.configuration.optimistic
          settlement_response = settle_payment(@verified_payment)

          unless settlement_response && settlement_response["success"]
            render_402_response(required_payment)
          end
        end
      end
    end

    private

    def facilitator_client
      @facilitator_client ||= X402Payments::FacilitatorClient.new
    end

    # Best-effort settlement after response — does not block access if it fails
    def settle_deferred_payment
      settle_payment(@verified_payment) if X402Payments.configuration.optimistic && @verified_payment.is_a?(Hash)
    end

    def render_402_response(required_payment)
      response.headers["PAYMENT-REQUIRED"] = Base64.strict_encode64(required_payment.to_json)
      render json: { error: "Payment required" }, status: :payment_required
    end

    def generate_required_payment(options)
      # Basic validation: ensure required parameters are present
      raise ArgumentError.new("amount is required") unless options[:amount].present?

      updated_options = options.merge({
        resource: request.original_url,
        description: "Payment required to access #{request.path}"
      })

      begin
        X402Payments::ClientMessaging::PaymentRequiredResponse.generate(updated_options)
      rescue X402Payments::ClientMessaging::InvalidPaymentOptionsError, X402Payments::ConfigurationError => e
        raise ArgumentError.new("Invalid payment options: #{e.message}")
      end
    end

    def verify_payment(payment_header, required_payment)
      # decode payment header received from client
      begin
        payment_payload = decode_header(payment_header)
      rescue X402Payments::InvalidPaymentError => e
        Rails.logger.warn "Invalid payment header: #{e.message}"
        return nil
      end

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
        facilitator_client.verify_payment(settlement_request[:paymentPayload], settlement_request[:paymentRequirements])
      rescue X402Payments::InvalidPaymentError => e
        Rails.logger.error "Invalid payment: #{e.message}"
        return nil
      rescue X402Payments::FacilitatorError => e
        Rails.logger.error "Facilitator error: #{e.message}"
        return nil
      rescue => e
        Rails.logger.error "Unexpected error during payment verification: #{e.message}"
        return nil
      end

      settlement_request
    end

    def settle_payment(settlement_request)
      begin
        settlement_response = facilitator_client.settle_payment(settlement_request[:paymentPayload], settlement_request[:paymentRequirements])

        if settlement_response["success"]
          Rails.logger.info "Payment settled successfully: #{settlement_response.inspect}"
          response.headers["PAYMENT-RESPONSE"] = Base64.strict_encode64(settlement_response.to_json)
        else
          Rails.logger.warn "Settlement unsuccessful: #{settlement_response.inspect}"
        end

        settlement_response
      rescue X402Payments::FacilitatorError => e
        Rails.logger.error "Facilitator error during settlement: #{e.message}"
        nil
      rescue StandardError => e
        Rails.logger.error "Unexpected error during payment settlement: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        nil
      end
    end

    def decode_header(payment_header)
      decoded = Base64.decode64(payment_header)
      JSON.parse(decoded, symbolize_names: true)
    rescue => e
      safe_message = e.message.encode("UTF-8", invalid: :replace, undef: :replace)
      Rails.logger.error "Failed to decode payment header: #{safe_message}"
      raise X402Payments::InvalidPaymentError, "Invalid payment signature header: #{safe_message}"
    end
  end
end
