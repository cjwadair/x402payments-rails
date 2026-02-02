module Instapay
  module ClientMessaging
    class AcceptedPaymentsBuilder
      def self.build(options = {})
        new.build(options)
      end

      def initialize
        @payment_resolver = AcceptedPaymentsResolver.new
        @payment_formatter = AcceptedPaymentsFormatter.new
      end

      def build(options = {})
        accepted_payments = @payment_resolver.resolve(
          accepts: options[:accepts],
          chain: options[:chain],
          currency: options[:currency]
        )

        accepted_payments.map do |payment|
          @payment_formatter.format(payment, options)
        end
      end
    end
  end
end
