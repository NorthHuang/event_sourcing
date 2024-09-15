# frozen_string_literal: true

module EventSourcing
  class Configuration
    attr_accessor :event_record_class
    attr_accessor :event_store
    attr_accessor :aggregate_repository
    attr_accessor :command_handlers
    attr_accessor :event_handlers
    attr_accessor :command_service
    attr_accessor :event_publisher
    attr_accessor :assets_event_class
    attr_accessor :aggregate_loader
    attr_accessor :domain_loaders

    # This is to Assets V2 migration, to disable the side effect implementation
    attr_accessor :side_effect_enabled
    attr_accessor :snapshot_enabled
    attr_accessor :snapshot_class

    # write_event_only
    #   - This flag is useful for V1 to write event only
    #   - Disable validation in command handler for specify
    #   - Disable aggregate account wallet update
    #
    # Current usage
    #   - McoLockup for crypto earn and crypto credit
    attr_accessor :write_event_only

    attr_reader :currency_cloud

    # this enables aggregate to be saved via memoization during preloading
    attr_accessor :memoization_store

    def self.instance
      @instance ||= new
    end

    def self.reset
      @instance = new
    end

    def initialize
      @event_store = EventSourcing::EventStore.new(self)
      @aggregate_repository = EventSourcing::AggregateRepository.new(self)
      @command_service = EventSourcing::CommandService.new(self)
      @event_publisher = EventSourcing::EventPublisher.new(self)
    end
  end
end
