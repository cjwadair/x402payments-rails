require "instapay/controller_extensions"

module Instapay
  class Railtie < ::Rails::Railtie
    initializer "instapay.controller_extensions" do
      ActiveSupport.on_load(:action_controller) do
        include Instapay::ControllerExtensions
      end
    end

    initializer "instapay.configuration" do
      # Configuration will be loaded from initializers/instapay.rb if it exists
    end
  end
end
