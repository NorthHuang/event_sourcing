# frozen_string_literal: true

require 'rspec'
require 'active_model'
require 'active_record'
require 'active_support/core_ext/module/concerning'

require 'event_sourcing/extentions'

require 'event_sourcing/helpers/attribute_support'
require 'event_sourcing/helpers/self_applier'

require 'event_sourcing/after_commit'
require 'event_sourcing/aggregate_repository'
require 'event_sourcing/aggregate_repository/aggregate_load_options'
require 'event_sourcing/aggregate_repository/domain_load_options'
require 'event_sourcing/state_machine'
require 'event_sourcing/aggregate_root'
require 'event_sourcing/base_type'
require 'event_sourcing/command_handler'
require 'event_sourcing/command_service'
require 'event_sourcing/command'
require 'event_sourcing/configuration'
require 'event_sourcing/core'
require 'event_sourcing/domain'
require 'event_sourcing/event_handler'
require 'event_sourcing/event_publisher'
require 'event_sourcing/event_record'
require 'event_sourcing/event_store'
require 'event_sourcing/event'
require 'event_sourcing/memoization_store/base'
require 'event_sourcing/memoization_store/request_store'
require 'event_sourcing/projector'
require "event_sourcing/after_outermost_commit"

require "event_sourcing/rspec/be_event"
require "event_sourcing/rspec/have_published"
require "event_sourcing/rspec/publish"
require "event_sourcing/rspec/have_applied"
require "event_sourcing/rspec/apply"
require "event_sourcing/rspec/matchers"


# Main EventSourcing namespace.
#
module EventSourcing
  module RSpec
    NotSupported = Class.new(StandardError)
  end
end

::RSpec.configure do |config|
  config.include ::EventSourcing::RSpec::Matchers
end
