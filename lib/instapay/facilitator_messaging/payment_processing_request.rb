module Instapay
  module FacilitatorMessaging
    class PaymentRequiredReqest
      def self.generate(payload, attributes = {})
        new(payload, attributes).generate
      end

      attr_accessor :payload, :attrs

      def initialize(payload, attributes = {})
        @payload = payload
        @attr = attributes
      end

      def generate

        requirement = build_requirement_object

        # request.env["x402.payment"] = {
        #   payer: validation_result[:payer],
        #   amount: payment_payload.value,
        #   network: payment_payload.network,
        #   payload: payment_payload,
        #   requirement: requirement,
        #   version: protocol_version
        # }


      end


      private

      def build_requirement_object
        {
          scheme: attrs[:scheme] || "exact",
          network: format_network(attrs[:network]),
          amount: attrs[:amount].to_s,
          asset: attrs[:asset],
          payTo: attrs[:pay_to],
          maxTimeoutSeconds: attrs[:max_timeout_seconds],
          extra: attrs[:extra]
        }.compact
      end

      
    end
  end
end