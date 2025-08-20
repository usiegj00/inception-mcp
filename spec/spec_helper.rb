# frozen_string_literal: true

require 'bundler/setup'
require 'rspec'
require 'inception/mcp'

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Allow longer timeouts for integration tests
  config.around(:each, type: :integration) do |example|
    original_timeout = RSpec.configuration.default_timeout
    RSpec.configuration.default_timeout = 30
    example.run
    RSpec.configuration.default_timeout = original_timeout
  end
end