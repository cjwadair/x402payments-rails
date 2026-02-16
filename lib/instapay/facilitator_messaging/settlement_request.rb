module Instapay
  module FacilitatorMessaging
    
    class InvalidSettlementRequestError < StandardError; end

    class SettlementRequest
      def self.generate(payload, accepted_payments)
        new(payload, accepted_payments).generate
      end

      attr_accessor :payload, :accepted_payments, :matching_accept

      def initialize(payload, accepted_payments)
        @payload = payload
        @accepted_payments = accepted_payments
        @matching_accept = nil
      end

      def generate

        puts "Payload: #{payload.inspect}"
        puts "accepted payments: #{accepted_payments.inspect}"

        find_matching_accept!
        validate_inputs!

        formatted_payload = build_formatted_payload
        payment_requirements = build_requirements_object

        {
          x402Version: 2,
          paymentPayload: formatted_payload,
          paymentRequirements: payment_requirements
        }
      end

      private

      def find_matching_accept!
        client_accepts = payload[:accepted]

        unless client_accepts
          raise InvalidSettlementRequestError, "Missing accepted payment info in payload"
        end

        @matching_accept = accepted_payments.find do |accept|
          accept[:scheme] == client_accepts[:scheme] &&
          accept[:network] == client_accepts[:network] &&
          accept[:amount].to_s == client_accepts[:amount].to_s &&
          accept[:asset] == client_accepts[:asset] &&
          accept[:payTo] == client_accepts[:payTo]
        end

        unless @matching_accept
          raise InvalidSettlementRequestError, "No matching accepted payment found"
        end
      end

      def validate_inputs!

        authorization = payload[:payload][:authorization]
        
        unless authorization
          raise InvalidSettlementRequestError, "Missing authorization in payload"
        end

        # For EVM chains, validate recipient and amount locally before sending to facilitator
        # For Solana chains, the facilitator handles all validation of the transaction
        if Instapay.evm_chain?(matching_accept[:network])
          #TODO -- Determine what else needs to be validated here before sending to the facilitator for validation -- need to make sure facilitator handles checking signature from and auth validity, etc
          # Validate recipient address

          # Validate scheme
          payload_scheme = payload[:accepted][:scheme]
          requirements_scheme = matching_accept[:scheme] || "exact"
          
          unless payload_scheme == requirements_scheme
            raise InvalidSettlementRequestError, "Scheme mismatch: expected #{requirements_scheme}, got #{payload_scheme}"
          end

          # Validate network
          unless payload[:accepted][:network] == matching_accept[:network]
            raise InvalidSettlementRequestError, "Network mismatch: expected #{matching_accept[:network]}, got #{payload[:accepted][:network]}"
          end
          
          unless authorization[:to]&.downcase == matching_accept[:payTo]&.downcase
            raise InvalidSettlementRequestError, "Recipient mismatch: expected #{matching_accept[:payTo]}, got #{authorization[:to]}"
          end

          # Validate amount
          payment_value = authorization[:value].to_i
          required_value = matching_accept[:amount].to_i

          if payment_value < required_value
            raise InvalidSettlementRequestError, "Insufficient amount: expected at least #{required_value}, got #{payment_value}"
          end
        else
          # Solana: verify transaction payload exists
          unless payload[:transaction]
            raise InvalidSettlementRequestError, "Solana payment missing transaction payload"
          end
        end
      end

      def build_requirements_object
        {
          scheme: matching_accept[:scheme] || "exact",
          network: matching_accept[:network],
          amount: matching_accept[:amount].to_s,
          asset: matching_accept[:asset],
          payTo: matching_accept[:payTo],
          maxTimeoutSeconds: matching_accept[:maxTimeoutSeconds],
          extra: matching_accept[:extra]
        }.compact
      end

      def build_formatted_payload
        {
          x402Version: 2,
          accepted: payload[:accepted],
          payload: payload[:payload],
          extensions: {},
          resource: payload[:resource]
        }
      end
      
    end
  end
end