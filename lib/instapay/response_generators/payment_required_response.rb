module Instapay
  module ResponseGenerators
    class PaymentRequiredResponse
      def self.generate(options = {})
        new.generate(options)
      end

      def initialize
        @payment_resolver = AcceptedPaymentsResolver.new
        @payment_formatter = AcceptedPaymentsFormatter.new
      end

      def generate(options = {})
        accepted_payments = build_accepted_payments_object(options)
        build_response_object(
          accepts: accepted_payments,
          resource_url: options[:resource],
          description: options[:description]
        )
      end

      private

      def build_accepted_payments_object(options)
        accepted_payments = @payment_resolver.resolve(
          accepts: options[:accepts],
          chain: options[:chain],
          currency: options[:currency]
        )

        accepted_payments.map do |payment|
          @payment_formatter.format(payment, options)
        end
      end

      def build_response_object(accepts:, resource_url:, description:)
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
    end
  end
end