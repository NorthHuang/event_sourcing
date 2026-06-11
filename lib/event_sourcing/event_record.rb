# frozen_string_literal: true

module EventSourcing
  module SerializesEvent
    def event
      _event =
        Class.const_get(
          "#{self.class.event_module}::#{self.event_type.camelize}"
        ).new(
          parent_id: parent_id,
          aggregate_id: aggregate_id,
          version: version,
          created_at: created_at
        )
      _event.domain_id = domain_id
      _event.payload = event_payload.symbolize_keys
      _event
    end

    def event=(event)
      self.parent_id = event.parent_id
      self.aggregate_id = event.aggregate_id
      self.version = event.version
      self.created_at = event.created_at
      self.event_type = event.type
      self.event_payload = event.payload
      self.domain_id = event.domain_id
      self.domain_type = event.domain_type
    end
  end

  class EventRecord < ActiveRecord::Base
    include SerializesEvent

    self.abstract_class = true

    validates_presence_of :aggregate_id, :version, :created_at, :event_type

    class << self
      attr_accessor :event_module
    end
  end
end
