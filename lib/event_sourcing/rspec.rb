# frozen_string_literal: true

require 'rspec'
require 'event_sourcing'

module EventSourcing
  module RSpec
    NotSupported = Class.new(StandardError) unless const_defined?(:NotSupported)
  end
end

require "event_sourcing/rspec/be_event"
require "event_sourcing/rspec/have_published"
require "event_sourcing/rspec/publish"
require "event_sourcing/rspec/have_applied"
require "event_sourcing/rspec/apply"
require "event_sourcing/rspec/matchers"

::RSpec.configure do |config|
  config.include ::EventSourcing::RSpec::Matchers
end
