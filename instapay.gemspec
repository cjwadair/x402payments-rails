require_relative "lib/instapay/version"

Gem::Specification.new do |spec|
  spec.name        = "instapay"
  spec.version     = Instapay::VERSION
  spec.authors     = [ "cjwadair" ]
  spec.email       = [ "cjwadair@gmail.com" ]
  # spec.homepage    = "TODO"
  spec.summary     = "x402 micropayments for Rails."
  spec.description = "Instapay is a Rails engine that simplifies the integration of x402 micropayments into your Rails applications, enabling seamless and efficient payment processing."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 8.1"
  spec.add_dependency "faraday", "~> 2.1"

  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "vcr", "~> 6.0"
end
