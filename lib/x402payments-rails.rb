# frozen_string_literal: true

require "x402_payments/version"
require "x402_payments/railtie"
require "x402_payments/configuration"
require "x402_payments/chains"
require "x402_payments/controller_extensions"
require "x402_payments/facilitator_client"
require "x402_payments/client_messaging/accepted_payments_resolver"
require "x402_payments/client_messaging/accepted_payments_formatter"
require "x402_payments/client_messaging/accepted_payments_builder"
require "x402_payments/client_messaging/payment_required_response"
require "x402_payments/facilitator_messaging/settlement_request"

module X402Payments
	extend Chains

	class << self
		def configuration
			@configuration ||= Configuration.new
		end

		def configure(&block)
			block.call(configuration)
			configuration.validate!
		end

		def reset_configuration!
			@configuration = Configuration.new
		end
	end
end