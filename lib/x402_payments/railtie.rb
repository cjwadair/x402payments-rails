require "x402_payments/controller_extensions"

module X402Payments
  class Railtie < ::Rails::Railtie
		initializer "x402_payments.controller_extensions" do
      ActiveSupport.on_load(:action_controller) do
        include X402Payments::ControllerExtensions
      end
    end

		initializer "x402_payments.configuration" do
			# Configuration will be loaded from initializers/x402_payments.rb if it exists
    end
  end
end
