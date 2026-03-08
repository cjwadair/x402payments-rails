# x402payments-rails
Add support for x402 micropayments to any controller endpoint with a single line of code.

This gem is currently in active development and breaking changes are possible.

## Installation
Add the following to your application's Gemfile:

```ruby
gem "x402payments-rails"
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install x402payments-rails
```

## Configuration
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
  config.optimistic = false
end
```

## Usage Patterns

### Protect a single endpoint
Protect a single endpoint with 'require_x402_payment':
```
class Api::PremiumController < ApplicationController
  def forecast
    require_x402_payment({amount: 0.01, chain: 'base'})
    render json: forecast_data
  end
end
```

### Protect all controller endpoints 
add a before_action to protect all controller endpoints:
```
class Api::PremiumController < ApplicationController

  #all controller endpoints are protected except the free_info endpoint
  before_action :require_payment, except: [:free_info]

  def forecast
    render json: {message: "this endpoint is paywalled"}
  end

  def free_info
    render json: {message: "this endpoint in not paywalled"}
  end

  private 

  def require_payment
    require_x402_payment({amount: 0.01, chain: 'base'})
  end
end
```

#### `require_x402_payment` arguments

Method signature:

```ruby
require_x402_payment(options = {})
```

Required option:

- `amount` (`Numeric` or numeric `String`): payment amount in display units (for example, `0.01` USDC).

Optional options:

- `chain` (`String`): chain/network to accept. Can be a network name like `"base-sepolia"` or CAIP-2 like `"eip155:84532"`.
- `currency` (`String`): token symbol, for example `"USDC"` (defaults to configured currency).
- `wallet_address` (`String`): recipient wallet override (defaults to configured wallet address).
- `accepts` (`Array<Hash>`): explicit list of accepted payment methods. Each entry supports:
  - `:chain`
  - `:currency`
  - `:wallet_address`
- `fee_payer` (`String`): optional Solana fee payer override.

Example (single payment method):

```ruby
require_x402_payment(
  amount: 0.01,
  chain: "base-sepolia",
  currency: "USDC"
)
```

Example (multiple accepted methods):

```ruby
require_x402_payment(
  amount: 0.01,
  accepts: [
    { chain: "base-sepolia", currency: "USDC", wallet_address: ENV["BASE_WALLET"] },
    { chain: "solana-devnet", currency: "USDC", wallet_address: ENV["SOLANA_WALLET"] }
  ]
)
```

## Configuration Options

### Adding Custom Chains and Tokens

By default, x402payments-rails supports USDC payments on: `base`, `base-sepolia`, `avalanche`, `avalanche-fuji`, `solana`, and `solana-devnet`.

You can register additional EVM chains and tokens in your initializer:

```ruby
X402Payments.configure do |config|
  config.wallet_address = ENV["X402_WALLET_ADDRESS"]

  # Register a custom EVM chain (currently only eip155 is supported)
  config.register_chain(
    name: "polygon",
    chain_id: 137,
    standard: "eip155"
  )

  # Register a token for that chain
  config.register_token(
    chain: "polygon",
    symbol: "USDT",
    address: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
    decimals: 6,
    name: "Tether USD",
    version: "2"
  )
end
```

Then reference the registered chain/token in your controller:

```ruby
require_x402_payment(
  amount: 0.01,
  accepts: [
    { chain: "polygon", currency: "USDT", wallet_address: ENV["POLYGON_WALLET"] }
  ]
)
```

Notes:

- `register_chain` supports only `standard: "eip155"`.
- `register_token` keys are matched by `chain + symbol` (case-insensitive).
- If a token is not known for a chain, the gem raises: `Unknown token ... Register with config.register_token()`.

### Accepting Multiple Payment Options

By default, `required_x402_payment` will accept payment based on the values set using `config.chain` and `config.currecy`.

To allow customs to pay via any of several chains, use the `config.accept()` method:

```ruby
X402.configure do |config|
  ... existing config variables...

  # Accept payments on multiple chains
  config.accept(chain: "base-sepolia", currency: "USDC")
  config.accept(chain: "polygon-amoy", currency: "USDC")
end
```

Optionally, you can specify different receipient wallet addresses per chain:
```ruby
  config.accept(chain: "base-sepolia", currency: "USDC", wallet_address: "0xWallet1")
  config.accept(chain: "polygon-amoy", currency: "USDC", wallet_address: "0xwallet2")
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
