# frozen_string_literal: true

module EventSourcing
  class Projector
    include Helpers::SelfApplier

    def initialize(configuration)
      @configuration = configuration
    end

    # TODO: change to use callback get_event and cursor
    def replay_for(aggregate_id)
      remove(aggregate_id)
      events = event_store.load_events(aggregate_id: aggregate_id)
      events.each { |event| handle_message(event) }
    end

    def remove(aggregate_id)
      raise 'destroy not implemented yet'
    end

    def repository
      @configuration.aggregate_repository
    end

    private

    def event_store
      @configuration.event_store
    end
  end
end
