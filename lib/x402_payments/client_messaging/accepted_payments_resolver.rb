module X402Payments
  module ClientMessaging
    class AcceptedPaymentsResolver
      def resolve(accepts:, chain:, currency:)
        if accepts.present?
          build_from_accepts_array(accepts)
        elsif chain.present?
          build_from_chain(chain, currency)
        else
          use_default_payments
        end
      end

      private

      def build_from_accepts_array(accepts)
        accepts.map do |acc|
          {
            chain: acc[:chain],
            currency: acc[:currency] || X402Payments.configuration.currency || "USDC",
            wallet_address: acc[:wallet_address]
          }
        end
      end

      def build_from_chain(chain, currency)
        [ {
          chain: chain,
          currency: currency || X402Payments.configuration.currency || "USDC",
          wallet_address: nil
        } ]
      end

      def use_default_payments
        X402Payments.configuration.default_accepted_payments
      end
    end
  end
end
