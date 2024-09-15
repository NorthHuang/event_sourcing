# frozen_string_literal: true

module EventSourcing
  class EventPublisher
    class PublishEventError < RuntimeError
      attr_reader :event_handler_class, :event

      def initialize(event_handler_class, event)
        @event_handler_class = event_handler_class
        @event = event
      end

      def message
        "Event Handler: #{@event_handler_class.inspect}\nEvent: #{
          @event.inspect
        }\nCause: #{cause.inspect}"
      end
    end

    def initialize(configuration)
      @configuration = configuration
    end

    def publish_events(events, entity_or_nil)
      events.each { |event| process_event(event, entity_or_nil) }
    end

    private

    def process_event(event, entity_or_nil)
      event_handlers.each do |handler|
        handler.handle_message(event, entity_or_nil)
      rescue => ex
        # TODO: add config for logging
        puts ex.message
        puts ex.backtrace
        if defined?(Bugsnag)
          Bugsnag.notify(ex)
        end
        raise PublishEventError.new(handler.class, event)
      end
    end

    def event_handlers
      @configuration.event_handlers
    end
  end
end
