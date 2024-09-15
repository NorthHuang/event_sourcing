# frozen_string_literal: true

module EventSourcing
  class Event
    include Helpers::AttributeSupport

    attrs :parent_id, String
    attrs :aggregate_id, String
    attrs :version, Integer
    attrs :created_at, DateTime

    class << self
      attr_reader :domain_id_attribute
    end

    def self.domain_id=(attribute)
      @domain_id_attribute = attribute
      class_eval <<EOS
        def domain_id
          @#{attribute}
        end
EOS
      class_eval <<EOS
        def domain_id=(value)
          @#{attribute} = value
        end
EOS
    end

    def self.domain_type=(type)
      class_eval <<EOS
        def domain_type
          "#{type}"
        end
EOS
    end

    def payload=(args = {})
      super if defined?(super)
      args = args.with_indifferent_access
      (self.class.attr_types || {}).except(self.class.domain_id_attribute)
        .each do |attribute, type|
        if args.has_key? attribute
          update_attribute_with_type(attribute, args[attribute])
        end
      end
    end

    def payload
      super if defined?(super)
      (self.class.attr_types || {}).except(self.class.domain_id_attribute)
        .each_with_object({}).each do |(attribute, type), hash|
        hash[attribute] = send attribute
      end
    end

    # @deprecate
    def self.payloads=(attributes)
      @payload_attributes = attributes
    end

    def initialize(args)
      update_all_attributes args
      raise 'Missing aggregate_id' unless @aggregate_id
      raise 'Missing version' unless @version
      @created_at = created_at || DateTime.now
    end

    # Assets::Events::Viban::DepositCreatedEvent to viban/deposit_created_event
    def self.event_type
      self.to_s.split('::')[2..-1].join('::').underscore
    end

    def domain_type
      nil
    end

    def domain_id
      nil
    end

    def domain_id=(value)
      nil
    end

    def type
      self.class.event_type
    end
  end
end
