# frozen_string_literal: true

module X402Payments
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class FacilitatorError < Error; end
  class InvalidPaymentError < Error; end

  module ClientMessaging
    class InvalidPaymentOptionsError < X402Payments::Error; end
  end

  module FacilitatorMessaging
    class InvalidSettlementRequestError < X402Payments::Error; end
  end
end
