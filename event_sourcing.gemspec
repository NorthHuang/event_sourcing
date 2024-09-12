# -*- encoding: utf-8 -*-
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require_relative 'lib/event_sourcing/version'
ruby_version = File.read(File.join(__dir__, "../.ruby-version")).gsub(/ruby-/, "")

Gem::Specification.new do |s|
  s.name        = "event_sourcing"
  s.version     = ::EventSourcing::VERSION
  s.date        = '2024-09-12'
  s.summary     = 'Event Sourcing'
  s.authors     = ['ZileHuang']
  s.email       = ['hzl136133@gmail.com']
  s.license     = "MIT"
  s.homepage    = "https://github.com/NorthHuang"
  s.files       = `find *`.split("\n").uniq.sort.select { |f| !f.empty? }
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= #{ruby_version}")

  s.add_dependency 'activerecord', '>= 3.0', '<= 6.1.3.1'
  s.add_dependency 'activesupport', '>= 3.0'
  s.add_dependency 'request_store', '>= 1.5.0'

  s.add_runtime_dependency 'rspec', '>= 3.0'

  s.add_development_dependency 'bundler', '>= 2.2.24'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'factory_bot'
  s.add_development_dependency 'rspec_junit_formatter'
end
