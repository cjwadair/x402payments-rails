require "instapay/version"
require "instapay/railtie"
require "instapay/configuration"
require "instapay/controller_extensions"
require "instapay/response_generators/requirements_response"

module Instapay

  class << self
    def configuration
      Configuration.configuration
    end

    def configure(&block)
      Configuration.configure(&block)
    end

    def reset_configuration!
      Configuration.reset_configuration!
    end
  end

  # Chain configurations for supported networks
  CHAINS = {
    "base-sepolia" => {
      chain_id: 84532,
      usdc_address: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      explorer_url: "https://sepolia.basescan.org"
    },
    "base" => {
      chain_id: 8453,
      usdc_address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      explorer_url: "https://basescan.org"
    },
    "avalanche-fuji" => {
      chain_id: 43113,
      usdc_address: "0x5425890298aed601595a70AB815c96711a31Bc65",
      explorer_url: "https://testnet.snowtrace.io"
    },
    "avalanche" => {
      chain_id: 43114,
      usdc_address: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
      explorer_url: "https://snowtrace.io"
    },
    "solana-devnet" => {
      chain_id: 103,
      usdc_address: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
      explorer_url: "https://explorer.solana.com/?cluster=devnet",
      fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5"
    },
    "solana" => {
      chain_id: 101,
      usdc_address: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
      explorer_url: "https://explorer.solana.com",
      fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5"
    }
  }.freeze

  # Currency configurations by chain
  CURRENCY_BY_CHAIN = {
    "base-sepolia" => {
      symbol: "USDC",
      decimals: 6,
      name: "USDC",  # Testnet uses "USDC"
      version: "2"
    },
    "base" => {
      symbol: "USDC",
      decimals: 6,
      name: "USD Coin",  # Mainnet uses "USD Coin"
      version: "2"
    },
    "avalanche-fuji" => {
      symbol: "USDC",
      decimals: 6,
      name: "USD Coin",  # Testnet uses "USD Coin"
      version: "2"
    },
    "avalanche" => {
      symbol: "USDC",
      decimals: 6,
      name: "USDC",  # Mainnet uses "USDC"
      version: "2"
    },
    "solana-devnet" => {
      symbol: "USDC",
      decimals: 6,
      name: "USDC",
      version: nil
    },
    "solana" => {
      symbol: "USDC",
      decimals: 6,
      name: "USD Coin",
      version: nil
    }
  }.freeze

  CAIP2_MAPPING = {
    "base-sepolia" => "eip155:84532",
    "base" => "eip155:8453",
    "avalanche-fuji" => "eip155:43113",
    "avalanche" => "eip155:43114",
    "solana-devnet" => "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
    "solana" => "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"
  }.freeze

  REVERSE_CAIP2_MAPPING = CAIP2_MAPPING.invert.freeze

  SOLANA_CHAINS = %w[solana solana-devnet].freeze

  def self.solana_chain?(chain_name)
    SOLANA_CHAINS.include?(chain_name)
  end

  #NOTE -- NEED TO REVIEW AND FIGURE OUT BEST WAY TO HANDLE FEE_PAYER CONFIGURATION (IF NEEDED)
  def self.fee_payer_for(chain_name)
    # Priority: 1) Programmatic config, 2) Per-chain ENV variable, 3) Generic ENV variable, 4) Default from CHAINS
    config = configuration

    # Check programmatic configuration
    return config.fee_payer if config.fee_payer && !config.fee_payer.empty?

    # Check per-chain environment variable (e.g., X402_SOLANA_DEVNET_FEE_PAYER, X402_SOLANA_FEE_PAYER)
    env_var_name = "X402_#{chain_name.upcase.gsub('-', '_')}_FEE_PAYER"
    env_fee_payer = ENV[env_var_name]
    return env_fee_payer if env_fee_payer && !env_fee_payer.empty?

    # Check generic environment variable
    env_fee_payer = ENV["X402_FEE_PAYER"]
    return env_fee_payer if env_fee_payer && !env_fee_payer.empty?

    #NOTE -- NOT IMPLEMENTED YET -- CHECK CUSTOM CHAIN CONFIGURATION
    # Fall back to default from chain config
    #either custom chain if a custom chain matching the chain_name exists, otherwise use built in chain mathcing chain_name or raise error
    chain_config = config.custom_chains[chain_name] || CHAINS[chain_name] || {}
    chain_config[:fee_payer]
  end
  
end
