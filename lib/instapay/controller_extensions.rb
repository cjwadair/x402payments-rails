module Instapay
  module ControllerExtensions
    extend ActiveSupport::Concern

    included do
      after_action :settle_payment_if_needed
    end

    # Optional: in a controller, call `before_action :enforce_paywall`
    # to run this hook ahead of every request.
    # def enforce_paywall(options = {})
    #   require_payment(options)
    # end

    #TODO -- ADD logic related to getting a request with a payment signature -- verify, settle, etc.
    def require_x402_payment(options = {})
      if request.headers['PAYMENT-SIGNATURE'].blank?
        render_payment_required(options)      
      else
        # TODO -- verify payment signature, settle payment, etc.
        settle_payment
      end
    end

    class_methods do
      def skip_paywall_enforcement(**options)
        skip_before_action :enforce_paywall, **options
      end
    end

    private

    def settle_payment_if_needed
      unless Instapay.configuration.optimistic
        settle_payment
      end
    end

    def settle_payment
      # whatever you want the after_action to do
      #add method missing error -- implement payment settlement logic here
      # raise NotImplementedError, "Implement payment settlement logic here"
    end

    def render_payment_required(options = {})
      raise ArgumentError.new("amount is required") unless options[:amount].present?

      updated_options = options.merge({
        resource: request.original_url,
        description: "Payment required to access #{request.path}",
      })

      #note -- add error handling here in case of an error generating the response object

      puts "Generating payment required response with options: #{updated_options.inspect}"
      response_object = Instapay::ResponseGenerators::PaymentRequiredResponse.generate(updated_options)

      render json: response_object, status: :payment_required
    end

  end
end