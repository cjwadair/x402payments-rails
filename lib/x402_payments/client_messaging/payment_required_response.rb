# frozen_string_literal: true

module X402Payments
  module ClientMessaging
    class PaymentRequiredResponse
      def self.generate(options = {})
        new.generate(options)
      end

      def generate(options = {})
        normalized_options = normalize_options!(options)
        validate_options!(normalized_options)

        accepted_payments = build_accepted_payments_object(normalized_options)

        build_response_object(
          accepts: accepted_payments,
          resource_url: normalized_options[:resource],
          description: normalized_options[:description]
        )
      end

      private

      def build_response_object(accepts:, resource_url:, description:)
        {
          x402Version: X402Payments::PROTOCOL_VERSION,
          error: "Payment required to access this resource",
          resource: {
            url: resource_url,
            description: description || "Payment required to access #{resource_url}",
            mimeType: "application/json"
          },
          accepts: accepts
        }
      end

      def normalize_options!(options)
        normalized = options.deep_dup

        # Strip currency symbols, commas, and whitespace from amount
        if normalized[:amount].is_a?(String)
          normalized[:amount] = normalized[:amount].gsub(/[$,\s]/, "")
        end

        # Reformat to CAIP2 if needed
        normalized[:chain] = normalize_chain(normalized[:chain])

        # Normalize currency to uppercase
        normalized[:currency] = normalize_currency(normalized[:currency])

        # Normalize wallet address (trim whitespace)
        normalized[:wallet_address] = normalize_wallet_address(normalized[:wallet_address])


        # TODO -- Add normalization to ensure the accepts array is correctly formatted
        if normalized[:accepts].is_a?(Array)
          normalized[:accepts] = normalized[:accepts].map do |accept|
            # Normalize each accept entry if needed
            accept[:chain] = normalize_chain(accept[:chain])
            accept[:currency] = normalize_currency(accept[:currency])
            accept[:wallet_address] = normalize_wallet_address(accept[:wallet_address])
            accept
          end
        end

        normalized
      end

      #converts from CAIP2 format to chain name if needed, otherwise returns original value
      def normalize_chain(chain)
        if chain.present? && chain.include?(":")
          chain_name = X402Payments.from_caip2(chain.to_s)
          chain = chain_name if chain_name.present?
        end
        chain
      end 

      def normalize_currency(currency)
        currency&.to_s&.upcase
      end

      def normalize_wallet_address(wallet_address)
        wallet_address&.strip rescue wallet_address
      end

      def validate_options!(options)
        validate_amount!(options[:amount])
        validate_chain!(options[:chain])
        validate_accepts!(options[:accepts])
        validate_currency!(options[:currency])
        validate_wallet_address!(options[:wallet_address], options[:chain])
      end

      def validate_amount!(amount)
        return unless amount.present?

        unless amount.is_a?(Numeric) || (amount.is_a?(String) && amount.match?(/\A\d+(\.\d+)?\z/))
          raise InvalidPaymentOptionsError, "amount must be a number, got: #{amount.inspect}"
        end

        if amount.to_f <= 0
          raise InvalidPaymentOptionsError, "amount must be positive, got: #{amount.to_f}"
        end
      end

      def validate_chain!(chain)
        return unless chain.present?

        known_chains = X402Payments::Chains::CHAINS.keys + X402Payments.configuration.custom_chains.keys
        unless known_chains.include?(chain.to_s)
          raise InvalidPaymentOptionsError, "Unsupported chain: #{chain}"
        end
      end

      def validate_accepts!(accepts)
        return unless accepts.present?

        unless accepts.is_a?(Array)
          raise InvalidPaymentOptionsError, "accepts must be an array, got: #{accepts.class}"
        end
      end

      def validate_currency!(currency)
        return unless currency.present?

        unless currency.is_a?(String)
          raise InvalidPaymentOptionsError, "currency must be a string, got: #{currency.class}"
        end
      end

      def validate_wallet_address!(wallet_address, chain)
        return unless wallet_address.present?

        unless wallet_address.is_a?(String) && wallet_address.length > 0
          raise InvalidPaymentOptionsError, "wallet_address must be a non-empty string"
        end

        if chain.present?
          if X402Payments.solana_chain?(chain)
            unless wallet_address.match?(/\A[A-Za-z0-9]{32,44}\z/)
              raise InvalidPaymentOptionsError, "wallet_address format is invalid for Solana: #{wallet_address}"
            end
          else
            unless wallet_address.match?(/\A0x[a-fA-F0-9]{40}\z/)
              raise InvalidPaymentOptionsError, "wallet_address format is invalid for EVM: #{wallet_address}"
            end
          end
        else
          unless wallet_address.match?(/\A0x[a-fA-F0-9]{40}\z/) || wallet_address.match?(/\A[A-Za-z0-9]{32,44}\z/)
            raise InvalidPaymentOptionsError, "wallet_address format is invalid: #{wallet_address}"
          end
        end
      end

      def build_accepted_payments_object(options)
        AcceptedPaymentsBuilder.build(options)
      end
    end
  end
end
