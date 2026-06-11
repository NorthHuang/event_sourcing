# frozen_string_literal: true

module EventSourcing
  class Configuration
    attr_accessor :event_store
    attr_accessor :aggregate_repository
    attr_accessor :command_handlers
    attr_accessor :event_handlers
    attr_accessor :command_service
    attr_accessor :event_publisher
    attr_accessor :aggregate_loader
    attr_accessor :domain_loaders

    # Allows applications to disable read-model or integration side effects while
    # still writing events.
    attr_accessor :side_effect_enabled
    attr_accessor :snapshot_enabled
    attr_accessor :snapshot_class

    # write_event_only
    #   - Useful for legacy migrations or backfills that should record events
    #     without running application-specific side effects.
    attr_accessor :write_event_only

    # this enables aggregate to be saved via memoization during preloading
    attr_accessor :memoization_store
    attr_accessor :error_reporter
    attr_accessor :silent_exception_reraise_errors

    def self.instance
      @instance ||= new
    end

    def self.reset
      @instance = new
    end

    def initialize
      @command_handlers = []
      @event_handlers = []
      @domain_loaders = {}
      @side_effect_enabled = true
      @snapshot_enabled = false
      @write_event_only = false
      @silent_exception_reraise_errors = []
      @event_store = EventSourcing::EventStore.new(self)
      @aggregate_repository = EventSourcing::AggregateRepository.new(self)
      @command_service = EventSourcing::CommandService.new(self)
      @event_publisher = EventSourcing::EventPublisher.new(self)
    end

    def event_record_class
      @event_record_class || @assets_event_class
    end

    def event_record_class=(klass)
      @event_record_class = klass
    end

    def assets_event_class
      event_record_class
    end

    def assets_event_class=(klass)
      @assets_event_class = klass
      @event_record_class ||= klass
    end

    def report_error(error, context: {})
      return unless error_reporter

      if error_reporter.respond_to?(:call)
        error_reporter.call(error, context)
      elsif error_reporter.respond_to?(:notify)
        error_reporter.notify(error)
      else
        raise ConfigurationError,
              "error_reporter must respond to #call or #notify"
      end
    end
  end
end
