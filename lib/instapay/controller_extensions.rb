module Instapay
  module ControllerExtensions
    extend ActiveSupport::Concern

    # included do
    #   after_action :settle_payment_if_needed
    # end

    # Optional: in a controller, call `before_action :enforce_paywall`
    # to run this hook ahead of every request.
    # def enforce_paywall(options = {})
    #   require_payment(options)
    # end

    def require_x402_payment(options = {})
      payment_header = request.headers['PAYMENT-SIGNATURE']
      response_object = generate_required_payment(options)
      if payment_header.blank?
        render_402_response(response_object)      
      else
        settle_payment(payment_header, response_object)
      end
    end

    # class_methods do
    #   def skip_paywall_enforcement(**options)
    #     skip_before_action :enforce_paywall, **options
    #   end
    # end

    private

    # def settle_payment_if_needed
    #   unless Instapay.configuration.optimistic
    #     settle_payment
    #   end
    # end

    def render_402_response(response_object)
      response.headers['PAYMENT-REQUIRED'] = Base64.strict_encode64(response_object.to_json)
      render json: {error: "Payment required"}, status: :payment_required
    end

    def generate_required_payment(options)
      # Basic validation: ensure required parameters are present
      raise ArgumentError.new("amount is required") unless options[:amount].present?

      updated_options = options.merge({
        resource: request.original_url,
        description: "Payment required to access #{request.path}",
      })

      puts "Generating payment required response with options: #{updated_options.inspect}"
      
      begin
        Instapay::ClientMessaging::PaymentRequiredResponse.generate(updated_options)
      rescue Instapay::ClientMessaging::InvalidPaymentOptionsError => e
        # Re-raise as ArgumentError so it's clear to the developer what went wrong
        raise ArgumentError.new("Invalid payment options: #{e.message}")
      end
    end

    def settle_payment(payment_header, required_payment)
      # payment header is base64 encode signed authorization payload
      # options is a hash including an amount and other optional values

      # decode payment header received from client
      payment_payload = decode_header(payment_header)

      # generate payment requirement details based on options provided
      # required_payment = generate_required_payment(options)
      
      # Build and validate settlement request object
      # This finds a matching accept and raises InvalidSettlementRequestError if:
      # - no matching accept is found
      # - data is internally inconsistent
      begin
        settlement_request = Instapay::FacilitatorMessaging::SettlementRequest.new(payment_payload, required_payment[:accepts]).generate
      rescue Instapay::FacilitatorMessaging::InvalidSettlementRequestError => e
        response = required_payment.merge({
          error: "Payment Type Not Accepted"
        })
        puts "Payment validation failed: #{e.message}" 
        return render_402_response(response)
      end

      # Verify and settle payment with the facilitator
      facilitator_client = Instapay::FacilitatorClient.new

      # Verify payment with facilitator (external verification)
      begin
        verify_result = facilitator_client.verify_payment(settlement_request[:paymentPayload], settlement_request[:paymentRequirements])
      rescue Instapay::InvalidPaymentError => e
        puts "Invalid payment: #{e.message}"
        return render_402_response(required_payment)
      rescue Instapay::FacilitatorError => e
        puts "Facilitator error: #{e.message}"
        return render_402_response(required_payment)
      end

      # Settle payment with facilitator
      settlement_response = facilitator_client.settle_payment(settlement_request[:paymentPayload], settlement_request[:paymentRequirements])

      # step5 - handle settlement response
      if settlement_response["success"]
        #payment settled successfully -- allow access to resource
        puts "Payment settled successfully: #{settlement_response.inspect}"
        render json: settlement_response[:body], status: :ok
      else
        #payment settlement failed -- respond with payment required
        return render_402_response(required_payment)
      end

    end

    def decode_header(payment_header)
      begin
        decoded = Base64.decode64(payment_header)
        JSON.parse(decoded, symbolize_names: true)
      rescue => e
        #TO DO - ADD A PAYMENT ERROR CLASS
        # raise Instapay::PaymentError, "Invalid payment signature header: #{e.message}"
        raise "Invalid payment signature header: #{e.message}"
      end
    end

    def set_payment_processing_attrs(matching_accept, resource = {})
      additional_attrs = {version: 2}
      additional_attrs[:resource_url] = resource[:url] if resource[:url]
      additional_attrs[:resource_description] = resource[:description] if resource[:description]
      additional_attrs[:resource_mime_type] = resource[:mimeType] if resource[:mimeType]

      matching_accept.merge(additional_attrs)
    end
  end
end