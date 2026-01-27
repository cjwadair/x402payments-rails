module Instapay
  class Railtie < ::Rails::Railtie
    initializer "instapay.controller_extensions" do
      ActiveSupport.on_load(:action_controller) do
        include Instapay::ControllerExtensions
      end
    end
  end
end
