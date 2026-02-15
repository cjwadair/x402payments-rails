require 'faraday'
require 'json'

module Instapay
  class FacilitatorClient

    def initialize(facilitator_url = nil)
      @facilitator_url = facilitator_url || Instapay.configuration.facilitator_url
    end

    def verify_payment(payment_payload, payment_requirements) 
      validate_request(payment_payload, payment_requirements)
      request_body = request_body(payment_payload, payment_requirements)

      ::Rails.logger.info("=== X402 Verify Request ===")
      ::Rails.logger.info("URL: #{@facilitator_url}/verify")
      ::Rails.logger.info("Request body: #{request_body}")
      
      response = connection.post("verify") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = request_body
      end

      ::Rails.logger.info("Response status: #{response.status}")
      ::Rails.logger.info("Response body: #{response.body}")

      handle_response(response, "verify")
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to verify payment: #{e.message}"
    end

    def settle_payment(payment_payload, payment_requirements)
      validate_request(payment_payload, payment_requirements)
      request_body = request_body(payment_payload, payment_requirements)
      
      response = connection.post("settle") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = request_body
      end

      handle_response(response, "settle")
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to settle payment: #{e.message}"
    end

    def supported_networks
      response = connection.get('supported')
      handle_response(response, "supported")
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to fetch supported networks: #{e.message}"
    end

    private

    def connection 
      Faraday.new(url: @facilitator_url) do |faraday|
        # faraday.request  :url_encoded
        # faraday.response :logger
        faraday.adapter  Faraday.default_adapter
      end
    end

    def handle_response(response, action)
      case response.status
      when 200..299
        body = JSON.parse(response.body)
        
        # For verify action, validate the response payload
        if action == "verify"
          # Check if response indicates success (could be 'success' or 'isValid' depending on API version)
          is_valid = body["isValid"] || body["success"]
          
          unless is_valid
            raise InvalidPaymentError, "Facilitator validation failed: #{body['invalidReason'] || body['error']}"
          end
          
          if body["payer"].nil?
            raise InvalidPaymentError, "Verification failed: no payer address returned"
          end
        end
        
        body
      when 400
        error_body = JSON.parse(response.body) rescue {}
        raise InvalidPaymentError, "Invalid payment: #{error_body['error'] || response.body}"
      when 500..599
        raise FacilitatorError, "Facilitator error (#{action}): #{response.status}"
      else
        raise FacilitatorError, "Unexpected response (#{action}): #{response.status}"
      end
    rescue JSON::ParserError => e
      raise FacilitatorError, "Failed to parse facilitator response: #{e.message}"
    end

    def request_body(payload, requirements)
      
      {
        x402Version: 2,
        authorization: payload[:authorization],
        signature: payload[:signature],
        payload: payload,
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

      required_fields = [:scheme, :network, :amount, :asset, :payTo]
      required_fields.each do |field|
        value = payment_requirements[field] || payment_requirements[field.to_s]
        if value.nil? || value.to_s.empty?
          raise InvalidPaymentError, "Payment requirements missing required field '#{field}'"
        end
      end
    end
  end


  class FacilitatorError < StandardError; end
  class InvalidPaymentError < StandardError; end
 
end