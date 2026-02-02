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
        find_matching_accept!
        validate_inputs!

        payment_requirements = build_requirements_object

        {
          x402Version:2,
          paymentPayload: payload,
          paymentRequirements: payment_requirements
        }
      end

      private

      def find_matching_accept!
        @matching_accept = accepted_payments.find do |accept|
          accept[:scheme] == payload[:accepted][:scheme] &&
          accept[:network] == payload[:accepted][:network] &&
          accept[:amount].to_s == payload[:accepted][:amount].to_s &&
          accept[:asset] == payload[:accepted][:asset] &&
          accept[:pay_to] == payload[:accepted][:pay_to]
        end

        unless @matching_accept
          raise InvalidSettlementRequestError, "No matching accepted payment found"
        end
      end

      def validate_inputs!
        # Validate scheme
        payload_scheme = payload[:accepted][:scheme] || payload.scheme
        requirements_scheme = matching_accept[:scheme] || "exact"
        
        unless payload_scheme == requirements_scheme
          raise InvalidSettlementRequestError, "Scheme mismatch: expected #{requirements_scheme}, got #{payload_scheme}"
        end

        # Validate network
        unless payload[:accepted][:network] == matching_accept[:network]
          raise InvalidSettlementRequestError, "Network mismatch: expected #{matching_accept[:network]}, got #{payload[:accepted][:network]}"
        end

        # For EVM chains, validate recipient and amount locally before sending to facilitator
        # For Solana chains, the facilitator handles all validation of the transaction
        if Instapay.evm_chain?(matching_accept[:network])
          # Validate recipient address
          unless payload[:accepted][:to]&.downcase == matching_accept[:pay_to]&.downcase
            raise InvalidSettlementRequestError, "Recipient mismatch: expected #{matching_accept[:pay_to]}, got #{payload[:accepted][:to]}"
          end

          # Validate amount
          payment_value = payload[:accepted][:value].to_i
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
          network: format_network(matching_accept[:network]),
          amount: matching_accept[:amount].to_s,
          asset: matching_accept[:asset],
          payTo: matching_accept[:pay_to],
          maxTimeoutSeconds: matching_accept[:max_timeout_seconds],
          extra: matching_accept[:extra]
        }.compact
      end

      def format_network(network)
      end
    end
  end
end