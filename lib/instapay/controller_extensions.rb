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

    #TODO -- ADD logic related to getting a request with a payment signature -- verify, settle, etc.
    def require_x402_payment(options = {})
      payment_header = request.headers['PAYMENT-SIGNATURE']
      if payment_header.blank?
        render_payment_required(options)      
      else
        # TODO -- verify payment signature, settle payment, etc.
        settle_payment(payment_header, options)
      end
    end

    class_methods do
      def skip_paywall_enforcement(**options)
        skip_before_action :enforce_paywall, **options
      end
    end

    private

    # def settle_payment_if_needed
    #   unless Instapay.configuration.optimistic
    #     settle_payment
    #   end
    # end

    def render_payment_required(options = {})
      raise ArgumentError.new("amount is required") unless options[:amount].present?

      response_object = generate_required_payment(options)

      response.headers['PAYMENT-REQUIRED'] = Base64.strict_encode64(JSON.generate(response_object))

      render json: {error: "Payment required"}, status: :payment_required
    end

    def generate_required_payment(options)
      updated_options = options.merge({
        resource: request.original_url,
        description: "Payment required to access #{request.path}",
      })

      #note -- add error handling here in case of an error generating the response object

      puts "Generating payment required response with options: #{updated_options.inspect}"
      Instapay::ClientMessaging::PaymentRequiredResponse.generate(updated_options)
    end

    def settle_payment(payment_header, options)
      # payment header is base64 encode signed authorization payload
      # options is a hash including an amount and other optional values
      
      # THIS IS ALL THE LOGIC USED ON CLIENT TO GENERATE THE PAYMENT SIGNATURE
      # nonce_bytes = SecureRandom.random_bytes(32)
      # nonce_hex = "0x#{nonce_bytes.unpack1('H*')}"

      # authorization = {
      #   from: sender_address,
      #   to: accepts[:pay_to],
      #   value: accepts[:amount],
      #   valid_after: valid_after,
      #   valid_before: valid_before,
      #   nonce: nonce_hex
      # }

      # V2::PayloadBuilder.build(
      #   authorization: {
      #     from: "0x1234567890abcdef1234567890abcdef12345678",
      #     to: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
      #     value: 10000,
      #     validAfter: 1740672089,
      #     validBefore: 1740672154,
      #     nonce: "0x3456789012345678901234567890123456789012345678901234567890123456"
      #   },
      #   signature: signature, #signed authorization to prove ownership of sender_address
      #   resource: {
      #     url: resource,
      #     description: description || "Payment required for #{resource}",
      #     mime_type: "application/json"
      #   },
      #   accepted: {
      #     scheme: "exact",
      #     network: "eip155:84532",
      #     amount: "10000",
      #     asset: asset_address,
      #     pay_to: recipient,
      #     max_timeout_seconds: config.max_timeout_seconds,
      #     extra: extra
      #   }
      # )

      # step1 - decode payment header received from client
      decoded_payment_header = decode_header(payment_header)

      updated_options = options.merge({
        resource: decoded_payment_header[:resource][:url],
        description: "Payment required to access #{request.path}",
      })
      
      # step2 - check that server accepts the payment as specified and respond with payment request if no
      requirements_data = Instapay::ClientMessaging::PaymentRequiredResponse.generate(updated_options)
      
      matching_accept = find_matching_accept(requirements_data[:accepts], decoded_payment_header)

      #step 3 -- handle cases where no matching accept found
      unless matching_accept
        #base64 encode and convert the requirements
        response = Base64.strict_encode64(JSON.generate(requirements_data))
        render json: response, status: :payment_required and return
      end

      # step3 - validate that payment header details are OK
      payment_processing_attrs = set_payment_processing_attrs(matching_accept, accepted_payments_object[:resource])

      request_object = Instapay::FacilitatorMessaging::PaymentProcessingRequest.new(decoded_payment_header, payment_processing_attrs).generate

      #validate the payment processing requirement object
      validation_result = Instapay::PaymentValidator.new(decoded_payment_header, request_object[:requirement]).validate!

      #handle invalid payment case
      unless validation_result[:valid]
        response = Base64.strict_encode64(JSON.generate(requirements_data))
        render json: response, status: :payment_required and return
      end

      # step4 - settle payment -- calls x402 facilitator with the payment payload and the payment requirement details and returns the settlement response from the facilitator



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

    def find_matching_accept(accepted_payments, payment_header)
      accepted_payments.find do |accept|
        accept[:scheme] == payment_header[:accepted][:scheme] &&
        accept[:network] == payment_header[:accepted][:network] &&
        accept[:amount].to_s == payment_header[:accepted][:amount].to_s &&
        accept[:asset] == payment_header[:accepted][:asset] &&
        accept[:pay_to] == payment_header[:accepted][:pay_to]
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