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
      # Validate payment payload
      raise InvalidPaymentError, "Payment payload cannot be nil" if payment_payload.nil?
      raise InvalidPaymentError, "Payment payload must be a Hash" unless payment_payload.is_a?(Hash)
      
      # Validate authorization
      authorization = payment_payload[:payload][:authorization] || payment_payload["authorization"]
      raise InvalidPaymentError, "Payment payload missing 'authorization'" if authorization.nil?
      
      validate_authorization(authorization)
      
      # Validate signature
      signature = payment_payload[:payload][:signature] || payment_payload["signature"]
      raise InvalidPaymentError, "Payment payload missing 'signature'" if signature.nil? || signature.to_s.empty?
      
      # Validate payment requirements
      raise InvalidPaymentError, "Payment requirements cannot be nil" if payment_requirements.nil?
      raise InvalidPaymentError, "Payment requirements must be a Hash" unless payment_requirements.is_a?(Hash)
      
      validate_payment_requirements(payment_requirements)
    end

    def validate_authorization(authorization)
      raise InvalidPaymentError, "Authorization must be a Hash" unless authorization.is_a?(Hash)
      
      required_fields = [:from, :to, :value, :validAfter, :validBefore, :nonce]
      required_fields.each do |field|
        value = authorization[field] || authorization[field.to_s]
        if value.nil? || value.to_s.empty?
          raise InvalidPaymentError, "Authorization missing required field '#{field}'"
        end
      end
    end

    def validate_payment_requirements(requirements)
      required_fields = [:scheme, :network, :amount, :asset, :payTo]
      required_fields.each do |field|
        value = requirements[field] || requirements[field.to_s]
        if value.nil? || value.to_s.empty?
          raise InvalidPaymentError, "Payment requirements missing required field '#{field}'"
        end
      end
      
      # Validate scheme is a known value
      scheme = requirements[:scheme] || requirements["scheme"]
      valid_schemes = ["exact", "range", "minimum"]
      unless valid_schemes.include?(scheme.to_s)
        raise InvalidPaymentError, "Invalid scheme '#{scheme}'. Must be one of: #{valid_schemes.join(', ')}"
      end
    end
  end


  class FacilitatorError < StandardError; end
  class InvalidPaymentError < StandardError; end
 
end