module Api
  class PremiumContentController < ApplicationController
    # before_action :authenticate_user!
    before_action :require_payment, except: [:free_info]

    def paywalled_info
      render json: {
        message: "This is premium content that requires payment to access.",
        items: ["Item 1", "Item 2", "Item 3"]
      }
    end

    def free_info
      render json: {
        message: "This is free content accessible to all users."
      }
    end

    def invalid_payment_info
      render json: {
        message: "This content simulates an invalid payment scenario."
      }
    end

    private

    def require_payment
      require_x402_payment(paywall_options)
    end

    def paywall_options
      {
        "paywalled_info" => {amount: 0.05},
        "free_info" => {amount: 0.00},
        "invalid_payment_info" => {}
      }.fetch(action_name, {amount: 0.01})
    end

  end
end