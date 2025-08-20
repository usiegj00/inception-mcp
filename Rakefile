# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc 'Run integration tests'
task :integration do
  ENV['RSPEC_PATTERN'] = 'spec/integration/**/*_spec.rb'
  Rake::Task[:spec].invoke
end

desc 'Run unit tests only'
task :unit do
  ENV['RSPEC_PATTERN'] = 'spec/unit/**/*_spec.rb'
  Rake::Task[:spec].invoke
end