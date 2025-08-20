# frozen_string_literal: true

require_relative "lib/inception/mcp/version"

Gem::Specification.new do |spec|
  spec.name = "inception-mcp"
  spec.version = Inception::MCP::VERSION
  spec.authors = ["Inception Team"]
  spec.email = ["dev@inception.dev"]

  spec.summary = "MCP server for Inception browser control"
  spec.description = "Model Context Protocol server that provides AI access to Inception-controlled browsers via CDP"
  spec.homepage = "https://github.com/usiegj00/inception-mcp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/usiegj00/inception-mcp"
  spec.metadata["changelog_uri"] = "https://github.com/usiegj00/inception-mcp/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "exe/*", "*.gemspec", "README.md", "Gemfile*"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "websocket-client-simple", "~> 0.6"
  spec.add_dependency "json", "~> 2.6"
  spec.add_dependency "thor", "~> 1.0"
  
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end