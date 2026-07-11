# frozen_string_literal: true

require_relative "lib/market_data_app/version"

Gem::Specification.new do |spec|
  spec.name = "market-data-app"
  spec.version = MarketDataApp::VERSION
  spec.authors = ["Alex O'Byrne"]
  spec.email = ["alex@aob.io"]

  spec.summary = "Ruby client for the MarketData.app API"
  spec.description = "Ruby client for the MarketData.app API"
  spec.homepage = "https://github.com/web2boomer/market-data-app"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "README.md", "Gemfile", "market-data-app.gemspec"]
  end
  spec.bindir = "exe"
  spec.executables = []
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 1.0"
end
