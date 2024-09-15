# frozen_string_literal: true

module EventSourcing
  class Domain
    include Helpers::AttributeSupport
    include Helpers::SelfApplier
    include StateMachine

    attr_accessor :configuration

    attr_reader :aggregate_id
    attr_reader :domain_id
    attr_reader :version
    attr_reader :uncommited_events

    attr_accessor :root

    delegate :next_version, to: :root

    def self.domain_type
      raise "missing implement domain_type in #{self}"
    end

    def self.load_from_history(configuration, events)
      event = events.first
      domain =
        self.new(
          configuration,
          event.aggregate_id,
          event.domain_id,
          parent_id: event.parent_id
        )
      events.each { |evt| domain.apply_event(evt) }
      domain
    end

    def initialize(configuration, aggregate_id, domain_id, parent_id: nil)
      @configuration = configuration

      @parent_id = parent_id
      @aggregate_id = aggregate_id
      @domain_id = domain_id
      @version = 0
      @uncommited_events = []
    end

    def attach_root(root)
      raise 'aggregate_id_not_match' if root.aggregate_id != @aggregate_id
      @root = root
    end

    def build_event(event_class, attrs)
      raise 'not respond to next_version' unless respond_to?(:next_version)
      event_class.new(
        attrs.merge(
          parent_id: @parent_id,
          aggregate_id: @aggregate_id,
          domain_type: self.class.domain_type,
          domain_id: @domain_id,
          version: next_version
        )
      )
    end

    def apply_event(event)
      handle_message(event)
      @version = event.version
      @root.apply_event(event) unless @root.nil?
    end

    def commited
      @uncommited_events = []
    end

    protected

    def apply(event_class, attrs)
      event = build_event(event_class, attrs)
      StateMachine.listen self, event.class do
        apply_event(event)
      end
      @uncommited_events << event
    end
  end
end
