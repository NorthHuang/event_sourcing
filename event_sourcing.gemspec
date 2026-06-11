# -*- encoding: utf-8 -*-
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require_relative 'lib/event_sourcing/version'

Gem::Specification.new do |s|
  s.name        = "event_sourcing"
  s.version     = ::EventSourcing::VERSION
  s.summary     = 'Event sourcing toolkit for Ruby and ActiveRecord applications'
  s.description = 'A small event sourcing toolkit with aggregates, commands, event records, snapshots, projectors, and optional RSpec matchers.'
  s.authors     = ['ZileHuang']
  s.email       = ['hzl136133@gmail.com']
  s.license     = "MIT"
  s.homepage    = "https://github.com/NorthHuang/event_sourcing"
  s.metadata    = {
    "homepage_uri" => s.homepage,
    "source_code_uri" => s.homepage,
    "rubygems_mfa_required" => "true"
  }
  s.files       = Dir.chdir(__dir__) do
    Dir[
      "lib/**/*",
      "CHANGELOG.md",
      "Gemfile",
      "LICENSE",
      "README.md",
      ".ruby-version",
      "#{s.name}.gemspec"
    ].select { |f| File.file?(f) }
  end
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2")

  s.add_dependency 'activerecord', '>= 6.1', '< 8.0'
  s.add_dependency 'activesupport', '>= 6.1', '< 8.0'
  s.add_dependency 'request_store', '>= 1.5.0', '< 2.0'

  s.add_development_dependency 'bundler', '>= 2.5', '< 5.0'
  s.add_development_dependency 'debug', '>= 1.7', '< 2.0'
  s.add_development_dependency 'factory_bot', '>= 6.0', '< 7.0'
  s.add_development_dependency 'rspec', '>= 3.12', '< 4.0'
  s.add_development_dependency 'rspec_junit_formatter', '>= 0.6', '< 1.0'
  s.add_development_dependency 'sqlite3', '>= 1.6', '< 3.0'
end
