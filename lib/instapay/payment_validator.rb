module Instapay
  class PaymentValidator

    attr_accessor :payment_payload, :requirement
    
    def initialize(payment_payload, requirement)
      @payment_payload = payment_payload
      @requirement = requirement
    end

    def validate!
      # Validate scheme
      unless payment_payload.scheme == requirement.scheme
        return validation_error("Scheme mismatch: expected #{requirement.scheme}, got #{payment_payload.scheme}")
      end

      # Validate network
      unless payment_payload.network == requirement.network
        return validation_error("Network mismatch: expected #{requirement.network}, got #{payment_payload.network}")
      end

      # For EVM chains, validate recipient and amount locally before calling facilitator
      # For Solana chains, the facilitator handles all validation of the transaction
      if payment_payload.evm_chain?
        # Validate recipient address
        unless payment_payload.to_address&.downcase == requirement.pay_to&.downcase
          return validation_error("Recipient mismatch: expected #{requirement.pay_to}, got #{payment_payload.to_address}")
        end

        # Validate amount
        payment_value = payment_payload.value.to_i
        required_value = requirement.max_amount_required.to_i

        if payment_value < required_value
          return validation_error("Insufficient amount: expected at least #{required_value}, got #{payment_value}")
        end
      else
        # Solana: verify transaction payload exists
        unless payment_payload.transaction
          return validation_error("Solana payment missing transaction payload")
        end
      end
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

  end
end