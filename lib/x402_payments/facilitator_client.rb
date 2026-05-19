# frozen_string_literal: true

require "faraday"
require "json"

module X402Payments
  class FacilitatorClient
    def initialize(facilitator_url = nil)
      @facilitator_url = facilitator_url || X402Payments.configuration.facilitator_url
    end

    def verify_payment(payment_payload, payment_requirements)
      validate_request(payment_payload, payment_requirements)
      request_body = request_body(payment_payload, payment_requirements)

      ::Rails.logger.debug("=== X402Payments Verify Request ===")
      ::Rails.logger.debug("URL: #{@facilitator_url}/verify")
      ::Rails.logger.debug("Request body: #{request_body}")

      response = connection.post("verify") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = request_body
      end

      ::Rails.logger.debug("Response status: #{response.status}")
      ::Rails.logger.debug("Response body: #{response.body}")

      handle_verify_response(response)
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to verify payment: #{e.message}"
    end

    def settle_payment(payment_payload, payment_requirements)
      validate_request(payment_payload, payment_requirements)
      request_body = request_body(payment_payload, payment_requirements)

      ::Rails.logger.debug("=== X402Payments Settle Request ===")
      ::Rails.logger.debug("URL: #{@facilitator_url}/settle")
      ::Rails.logger.debug("Request body: #{request_body}")

      response = connection.post("settle") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = request_body
      end

      ::Rails.logger.debug("Response status: #{response.status}")
      ::Rails.logger.debug("Response body: #{response.body}")

      handle_response(response)
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to settle payment: #{e.message}"
    end

    def supported_networks
      response = connection.get("supported")
      handle_response(response)
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to fetch supported networks: #{e.message}"
    end

    private

    def connection
      @connection ||= Faraday.new(url: @facilitator_url) do |faraday|
        faraday.options.timeout      = 5   # read timeout
        faraday.options.open_timeout = 2   # connect timeout
        faraday.adapter Faraday.default_adapter
      end
    end

    def handle_verify_response(response)
      body = handle_response(response)
      is_valid = body["isValid"] || body["success"]
      raise InvalidPaymentError, "Facilitator validation failed: #{body['invalidReason'] || body['error']}" unless is_valid
      raise InvalidPaymentError, "Verification failed: no payer address returned" if body["payer"].nil?
      body
    end

    def handle_response(response)
      case response.status
      when 200..299
        JSON.parse(response.body)
      when 400
        error_body = JSON.parse(response.body)
        raise InvalidPaymentError, "Invalid payment: #{error_body['error'] || response.body}"
      when 500..599
        raise FacilitatorError, "Facilitator error: #{response.status}"
      else
        raise FacilitatorError, "Unexpected response: #{response.status}"
      end
    rescue JSON::ParserError => e
      raise FacilitatorError, "Failed to parse facilitator response: #{e.message}"
    end

    def request_body(payload, requirements)
      {
        x402Version: X402Payments::PROTOCOL_VERSION,
        authorization: payload.dig(:payload, :authorization),
        signature: payload.dig(:payload, :signature),
        paymentPayload: payload,
        paymentRequirements: requirements
      }.to_json
    end

    def validate_request(payment_payload, payment_requirements)
      raise InvalidPaymentError, "Payment payload cannot be nil" if payment_payload.nil?
      raise InvalidPaymentError, "Payment payload must be a Hash" unless payment_payload.is_a?(Hash)

      payload_section = payment_payload[:payload] || payment_payload["payload"]
      if payload_section.nil?
        raise InvalidPaymentError, "Payment payload missing 'payload'"
      end
      unless payload_section.is_a?(Hash)
        raise InvalidPaymentError, "Payment payload 'payload' must be a Hash"
      end

      accepted = payment_payload[:accepted] || payment_payload["accepted"]
      if accepted.nil?
        raise InvalidPaymentError, "Payment payload missing 'accepted'"
      end
      unless accepted.is_a?(Hash)
        raise InvalidPaymentError, "Payment payload 'accepted' must be a Hash"
      end

      raise InvalidPaymentError, "Payment requirements cannot be nil" if payment_requirements.nil?
      raise InvalidPaymentError, "Payment requirements must be a Hash" unless payment_requirements.is_a?(Hash)

      required_fields = [ :scheme, :network, :amount, :asset, :payTo ]
      required_fields.each do |field|
        value = payment_requirements[field] || payment_requirements[field.to_s]
        if value.nil? || value.to_s.empty?
          raise InvalidPaymentError, "Payment requirements missing required field '#{field}'"
        end
      end
    end
  end
end
