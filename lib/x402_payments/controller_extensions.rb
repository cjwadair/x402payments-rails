# frozen_string_literal: true

module X402Payments
  module ControllerExtensions
    extend ActiveSupport::Concern

    included do
      after_action :settle_deferred_payment
    end

    def require_x402_payment(options = {})
      required_payment = generate_required_payment(options)
      payment_header   = request.headers["PAYMENT-SIGNATURE"]

      return render_402_response(required_payment) if payment_header.blank?

      @x402_verified_payment = verify_payment(payment_header, required_payment)

      return render_402_response(required_payment) unless @x402_verified_payment

      return if X402Payments.configuration.optimistic

      settlement_response = settle_payment(@x402_verified_payment)
      render_402_response(required_payment) unless settlement_response&.dig("success")
    end

    private

    def facilitator_client
      @facilitator_client ||= X402Payments::FacilitatorClient.new
    end

    # Best-effort settlement after response — does not block access if it fails
    def settle_deferred_payment
      settle_payment(@x402_verified_payment) if X402Payments.configuration.optimistic && @x402_verified_payment.is_a?(Hash)
    end

    def render_402_response(required_payment)
      response.headers["PAYMENT-REQUIRED"] = Base64.strict_encode64(required_payment.to_json)
      render json: { error: "Payment required" }, status: :payment_required
    end

    def generate_required_payment(options)
      # Basic validation: ensure required parameters are present
      raise ArgumentError, "amount is required" unless options[:amount].present?

      updated_options = options.merge({
        resource: request.original_url,
        description: "Payment required to access #{request.path}"
      })

      X402Payments::ClientMessaging::PaymentRequiredResponse.generate(updated_options)
    rescue X402Payments::ClientMessaging::InvalidPaymentOptionsError, X402Payments::ConfigurationError => e
      raise ArgumentError, "Invalid payment options: #{e.message}"
    end

    def verify_payment(payment_header, required_payment)
      # decode payment header received from client
      settlement_request = build_settlement_request(payment_header, required_payment)

      # Verify payment with facilitator (external verification)
      verify_with_facilitator(settlement_request)

      settlement_request
    rescue X402Payments::FacilitatorMessaging::InvalidSettlementRequestError => e
      required_payment.merge!(error: e.message)
      Rails.logger.warn "Payment validation failed: #{e.message}"
      nil
    rescue X402Payments::InvalidPaymentError => e
      Rails.logger.error "Invalid payment: #{e.message}"
      nil
    rescue X402Payments::FacilitatorError => e
      Rails.logger.error "Facilitator error: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Unexpected error during payment verification: #{e.message}"
      nil
    end

    def build_settlement_request(payment_header, required_payment)
      payment_payload = decode_header(payment_header)

      # Build and validate settlement request object
      # This finds a matching accept and raises InvalidSettlementRequestError if: no matching accept is found or data is internally inconsistent
      X402Payments::FacilitatorMessaging::SettlementRequest.generate(payment_payload, required_payment[:accepts])
    end

    def verify_with_facilitator(settlement_request)
      facilitator_client.verify_payment(settlement_request[:paymentPayload], settlement_request[:paymentRequirements])
    end


    def settle_payment(settlement_request)
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

    def decode_header(payment_header)
      decoded = Base64.strict_decode64(payment_header)
      JSON.parse(decoded, symbolize_names: true)
    rescue StandardError => e
      safe_message = e.message.encode("UTF-8", invalid: :replace, undef: :replace)
      Rails.logger.error "Failed to decode payment header: #{safe_message}"
      raise X402Payments::InvalidPaymentError, "Invalid payment signature header: #{safe_message}"
    end
  end
end
