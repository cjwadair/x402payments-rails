module Api
  class PremiumContentController < ApplicationController
    # before_action :authenticate_user!
    # before_action :ensure_premium_access
    before_action :enforce_paywall#, only: [:paywalled_info]

    def paywalled_info
      render json: {
        message: "Premium content list",
        items: ["Item 1", "Item 2", "Item 3"]
      }
    end

    def free_info
      render json: {
        message: "This is free content accessible to all users."
      }
    end

  end
end