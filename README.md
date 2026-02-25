# x402payments-rails
add support for x402 micropayments to any controller endpoint

## Installation
Add this line to your application's Gemfile:

```ruby
gem "x402payments-rails"
```

And then execute:
```bash
$ bundle. install
```

Or install it yourself as:
```bash
$ gem install x402payments-rails
```

## Getting Started

#### Configuration
Create `config/initializers/x402payments.rb` file and add the following:
```
X402Payments.configure do |config|
  #wallet address for receiving funds
  config.wallet_address = ENV["X402_WALLET_ADDRESS"]

  #your preferred x402 payment facilitator
  config.facilitator_url = "https://www.x402.org/facilitator"

  config.chain = "base-sepolia" #or 'base' to use mainnet
  
  # Default Currency to use
  config.currency = "USDC"

  #ensure payment has been settled before returning a response to the client
  config.optimistic = "false"
end
```

#### Protect a single endpoint
Protect a single endpoint with 'require_x402_payment':
```
class Api::PremiumController < ApplicationController

  before_action :require_payment, except: [:free_info]
  def forecast
    x402_paywall({amount: 0.01, chain: 'base'})
    render json: forecast_data
  end
```

#### Protect all controller endpoints 
alternatively, add a before_action to protect all controller endpoints:
```
class Api::PremiumController < ApplicationController

  #all controller endpoints are protected except the free_info endpoint
  before_action :require_payment, except: [:free_info]

  def forecast
    render json: forecast_data
  end

  def free_info
    render json: free_data
  end

  private 

  def require_payment
    x402_paywall({amount: 0.01, chain: 'base'})
  end
```

## Usage

add:
- option details for calls to require_x402_payment
- detailed configuration instructions
- instructions for adding custom chains and payment methods
- instructios for accepting multiple payment methods

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
