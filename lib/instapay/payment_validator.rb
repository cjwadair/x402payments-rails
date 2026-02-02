module Instapay
  class PaymentValidator

    attr_accessor :payment_payload, :payment_requirement
    
    def initialize(request_object)
      @payment_payload = request_object[:paymentPayload]
      @payment_requirement = request_object[:paymentRequirement]
    end

    def validate
      # Call facilitator to verify payment (does NOT settle on blockchain yet)
      validate_with_facilitator
    end

    private

    def validation_success(payer_address, data = {})
      {
        valid: true,
        payer: payer_address,
        data: data
      }
    end

    def validation_error(message)
      {
        valid: false,
        error: message
      }
    end

    def validate_with_facilitator
      begin
        verify_result = Instapay::FacilitatorClient.new.verify(payment_payload, payment_requirement)

        unless verify_result["isValid"]
          return validation_error("Facilitator validation failed: #{verify_result['invalidReason']}")
        end

        if verify_result["payer"].nil?
          return validation_error("Verification failed: no payer address returned")
        end

        validation_success(verify_result["payer"], verify_result)
      rescue InvalidPaymentError => e
        validation_error("Facilitator validation failed: #{e.message}")
      rescue FacilitatorError => e
        validation_error("Facilitator error: #{e.message}")
      end
    end

  end
end