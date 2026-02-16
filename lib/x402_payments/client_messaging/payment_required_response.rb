module X402Payments
  module ClientMessaging
    class InvalidPaymentOptionsError < StandardError; end

    class PaymentRequiredResponse
      def self.generate(options = {})
        new.generate(options)
      end

      def generate(options = {})
        normalized_options = normalize_options!(options)
        validate_options!(normalized_options)
        
        accepted_payments = build_accepted_payments_object(normalized_options)
        
        response = build_response_object(
          accepts: accepted_payments,
          resource_url: normalized_options[:resource],
          description: normalized_options[:description]
        )

        puts "X402Payments response object: #{response.inspect}"
        
        response
      end

      private

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

      def normalize_options!(options)
        normalized = options.dup
        
        # Strip currency symbols, commas, and whitespace from amount
        if normalized[:amount].is_a?(String)
          normalized[:amount] = normalized[:amount].gsub(/[$,\s]/, '')
        end
        
        # Reformat to CAIP2 if needed
        if normalized[:chain].present? && normalized[:chain].exclude?(":")
          # Convert CAIP2 format to chain name
          caip2 = X402Payments.to_caip2(normalized[:chain].to_s.downcase)
          normalized[:chain] = caip2 if caip2.present?
        end

        # Normalize currency to uppercase
        if normalized[:currency].present?
          normalized[:currency] = normalized[:currency].to_s.upcase
        end
        
        # Normalize wallet address (trim whitespace)
        if normalized[:wallet_address].is_a?(String)
          normalized[:wallet_address] = normalized[:wallet_address].strip
        end

        #TODO -- Add normalization to ensure the accepts array is correctly formatted
        if normalized[:accepts].is_a?(Array)
          normalized[:accepts] = normalized[:accepts].map do |accept|
            # Normalize each accept entry if needed
            accept
          end
        end
        
        normalized
      end

      def validate_options!(options)
        # Validate amount (detailed checks)
        if options[:amount].present?
          amount = options[:amount]
          
          # Check if amount is numeric
          unless amount.is_a?(Numeric) || (amount.is_a?(String) && amount.match?(/\A\d+(\.\d+)?\z/))
            raise InvalidPaymentOptionsError, "amount must be a number, got: #{amount.inspect}"
          end
          
          # Convert to float for validation
          amount_value = amount.to_f
          
          # Check if amount is positive
          if amount_value <= 0
            raise InvalidPaymentOptionsError, "amount must be positive, got: #{amount_value}"
          end
        end
        
        # Checks that supplied chain option is a suppored chain
        if options[:chain].present?
          chain = options[:chain]
          unless X402Payments.supported_chains.include?(chain.to_s.downcase)
            raise InvalidPaymentOptionsError, "Unsupported chain: #{chain}"
          end
        end
        
        # Validate accepts if provided (should be an array)
        if options[:accepts].present?
          unless options[:accepts].is_a?(Array)
            raise InvalidPaymentOptionsError, "accepts must be an array, got: #{options[:accepts].class}"
          end
        end
        
        # Validate currency if provided
        #TODO -- Add check if currency is supported
        if options[:currency].present?
          currency = options[:currency]
          unless currency.is_a?(String)
            raise InvalidPaymentOptionsError, "currency must be a string, got: #{currency.class}"
          end
        end
        
        # Validate wallet_address format if provided
        # TODO -- Add checks to confirm wallet address matches expected format and string length for a valid evm or solana wallet address
        if options[:wallet_address].present?
          wallet_address = options[:wallet_address]
          unless wallet_address.is_a?(String) && wallet_address.length > 0
            raise InvalidPaymentOptionsError, "wallet_address must be a non-empty string"
          end
        end
      end

      def build_accepted_payments_object(options)
        AcceptedPaymentsBuilder.build(options)
      end
    end
  end
end