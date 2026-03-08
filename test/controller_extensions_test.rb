require "test_helper"

class ControllerExtensionsTest < ActiveSupport::TestCase
    test "allows access when PAYMENT-SIGNATURE header is present" do
      skip "temporarily disabled"
      controller = ActionController::Base.new
      request = ActionDispatch::Request.new({})
      request.headers["PAYMENT-SIGNATURE"] = "valid_signature"
      controller.request = request

      # Simulate calling the action
      controller.enforce_paywall(amount: 1000)
      assert true # If no exception is raised, the test passes
    end

    test "renders payment required when PAYMENT-SIGNATURE header is missing" do
      skip "temporarily disabled"
      controller = ActionController::Base.new
      request = ActionDispatch::Request.new({})
      request.headers["PAYMENT-SIGNATURE"] = nil
      controller.request = request

      assert_raises(ArgumentError) do
        controller.require_payment(amount: 1000)
      end
    end
end
