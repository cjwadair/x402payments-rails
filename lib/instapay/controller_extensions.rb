module Instapay
  module ControllerExtensions
    extend ActiveSupport::Concern

    included do
      after_action :settle_payment_if_needed
    end

    # Optional: in a controller, call `before_action :enforce_paywall`
    # to run this hook ahead of every request.
    def enforce_paywall
      require_payment
    end

    def require_payment
      # whatever you want the before_action to do
    end

    class_methods do
      def skip_paywall_enforcement(**options)
        skip_before_action :enforce_paywall, **options
      end
    end

    private

    def settle_payment_if_needed
      settle_payment
    end

    def settle_payment
      # whatever you want the after_action to do
    end

  end
end