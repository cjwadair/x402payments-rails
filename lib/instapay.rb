# frozen_string_literal: true

require "instapay/version"
require "instapay/railtie"
require "instapay/configuration"
require "instapay/chains"
require "instapay/controller_extensions"
require "instapay/facilitator_client"
require "instapay/client_messaging/accepted_payments_resolver"
require "instapay/client_messaging/accepted_payments_formatter"
require "instapay/client_messaging/accepted_payments_builder"
require "instapay/client_messaging/payment_required_response"
require "instapay/facilitator_messaging/settlement_request"

module Instapay
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