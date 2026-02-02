require 'faraday'
require 'json'

module Instapay
  class FacilitatorClient

    def initialize(facilitator_url = nil)
      @facilitator_url = facilitator_url || Instapay.configuration.facilitator_url
    end

    def verify_payment(payment_payload, payment_requirements) 
      request_body = request_body(payment_payload, payment_requirements)
      
      response = connection.post("verify") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = request_body
      end

      handle_response(response, "verify")
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to verify payment: #{e.message}"
    end

    def settle_payment(payment_payload, payment_requirements)
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
        JSON.parse(response.body)
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
        paymentPayload: payload,
        paymentRequirements: requirements
      }.to_json
    end
  end


  class FacilitatorError < StandardError; end
  class InvalidPaymentError < StandardError; end
 
end