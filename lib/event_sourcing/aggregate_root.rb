# frozen_string_literal: true

module EventSourcing
  class AggregateRoot
    include Helpers::SelfApplier
    include Helpers::AttributeSupport
    include StateMachine

    attr_accessor :configuration # events which is used for buildidng the agge
    attr_accessor :applied_events # snapshot is assigned when load aggregate from repository
    attr_accessor :snapshot

    attr_reader :parent_id
    attr_reader :aggregate_id
    attr_reader :version
    attr_reader :uncommited_events

    DEFAULT_SNAPSHOT_INTERVAL = 100

    class << self
      attr_reader :plugins
      attr_accessor :snapshot_interval

      def inherited(subclass)
        subclass.snapshot_interval = DEFAULT_SNAPSHOT_INTERVAL
      end

      def snapshot_interval
        case @snapshot_interval
        when Proc
          @snapshot_interval.call
        when Numeric
          @snapshot_interval
        else
          raise "invalid snapshot_interval: #{@snapshot_interval}"
        end
      end

      def aggregate_type
        self.to_s.split('::')[2..-1].join('::').underscore
      end
    end

    def initialize(aggregate_id, parent_id: nil)
      @parent_id = parent_id
      @aggregate_id = aggregate_id
      @version = 0
      @uncommited_events = []
      @domains = {}
      @applied_events = []

      (self.class.plugins || []).each do |plugin|
        plugin.instance_method(:after_initialize).bind(self).call
      end
    end

    def next_version
      @version += 1
    end

    def build_event(event_class, attrs)
      event_class.new(
        attrs.merge(
          parent_id: @parent_id,
          aggregate_id: @aggregate_id,
          version: next_version
        )
      )
    end

    def apply_event(event)
      @version = event.version
      StateMachine.listen self, event.class do
        handle_message(event)
      end
      applied_events << event
    end

    def commited
      @uncommited_events = []
    end

    def load_domain(klass, domain_id)
      domain = get_domain(klass.domain_type, domain_id)
      return domain unless domain.nil?

      domain =
        repository.load_domain(
          klass,
          domain_id,
          parent_id: parent_id,
          aggregate_id: aggregate_id,
          until_version: version
        )
      domain.root = self
      store_domain(domain)
      domain
    end

    def self.plug(plugin)
      @plugins ||= []
      @plugins << plugin
      plugin.inject(self)
    end

    def load_from_history(events)
      events.each do |event|
        apply_event(event)
        clear_domain_store
      end
      self
    end

    def snapshot_takeable?
      snapshot_interval = self.class.snapshot_interval
      if applied_events.length < snapshot_interval
        return false
      end
      unless snapshot.nil?
        return (version - snapshot.event_version) >= snapshot_interval
      end

      true
    end

    MARSHAL_INGORE_VARIABLES = %i[
      @configuration
      @uncommited_events
      @domains
      @applied_events
      @snapshot
    ]
    def marshal_dump
      variables = instance_variables - MARSHAL_INGORE_VARIABLES
      Hash[variables.map { |name| [name, instance_variable_get(name)] }]
    end

    def marshal_load(data)
      data.each { |k, v| instance_variable_set(k, v) }
      @uncommited_events ||= []
      @domains ||= {}
      @applied_events ||= []
    end

    protected

    def apply(event_class, attrs)
      event = build_event(event_class, attrs)
      apply_event(event)
      @uncommited_events << event
    end

    def get_domain(domain_type, domain_id)
      return nil if @domains[domain_type].nil?
      @domains[domain_type][domain_id]
    end

    def store_domain(domain)
      domain_type = domain.class.domain_type
      @domains[domain_type] = {} if @domains[domain_type].nil?
      @domains[domain_type][domain.id] = domain
    end

    def clear_domain_store
      @domains = {}
    end

    def repository
      configuration.aggregate_repository
    end
  end

  module AggregateRoot::Plugin
    def after_initialize; end

    def inject(base)
      base.include(self::MainBlock)
    end

    concern :MainBlock do
      # main code block will include in aggregate root
    end # live cycle - called before end of initialize in aggregate root
  end
end
