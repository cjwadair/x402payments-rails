module Instapay
  module ClientMessaging
    class PaymentRequiredResponse
      def self.generate(options = {})
        new.generate(options)
      end

      def self.build_response(accepts:, resource_url:, description: nil)
        new.build_response_object(
          accepts: accepts,
          resource_url: resource_url,
          description: description
        )
      end

      def generate(options = {})
        accepted_payments = build_accepted_payments_object(options)
        response = build_response_object(
          accepts: accepted_payments,
          resource_url: options[:resource],
          description: options[:description]
        )
        puts "x402 response object: #{response.inspect}"
        response
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

      private

      def build_accepted_payments_object(options)
        AcceptedPaymentsBuilder.build(options)
      end
    end
  end
end