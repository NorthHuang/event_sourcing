# frozen_string_literal: true

# State machine for event-sourced aggregates and domains.
#
# @example
#   class Car
#     include EventSourcing::StateMachine
#
#     # Define state attribute to listen
#     attr_state :status
#
#     state :initialized, on_exit: []
#     state :pending, on_enter: []
#
#     transition from: :initialized, to: :pending, event: Events::StartedEvent
#
#     def initialize
#       @status = :initialized
#     end
#
#     def create
#       # validate the transition
#       # detect the state change and run callbacks
#       StateMachine.listen do
#         @status = :pending
#       end
#     end
#   end
module EventSourcing
  module StateMachine
    class StateMachineError < StandardError
      attr_reader :meta_data

      def initialize(meta_data)
        super(self.class)
        @meta_data = meta_data || {}
      end

      def message
        @meta_data.to_json
      end
    end
    class InvalidStateError < StateMachineError; end
    class InvalidTransitionError < StateMachineError; end

    def self.included(base)
      base.extend ClassMethods
    end

    # Listen to the state change and execute the lifecycle hooks
    #
    # @param obj [Object] instance with included StateMachine
    # @param event [Class, EventSourcing::Event] event class or event instance
    def self.listen(obj, event)
      unless obj.class.state_machine_enabled
        yield
        return
      end

      if obj.respond_to? :state_machine_enabled
        unless obj.state_machine_enabled
          yield
          return
        end
      end
      from_state = obj.current_state
      raise_if_invalid_state(obj, from_state)
      obj.handle_state_exit(from_state)

      yield

      to_state = obj.current_state
      raise_if_invalid_state(obj, to_state)

      unless deleted_event?(event)
        transition =
          obj.class.find_transition(
            from: from_state, to: to_state, event: event_class(event)
          )
        if transition.nil?
          raise InvalidTransitionError.new(
            from: from_state, to: to_state, event: event_name(event)
          )
        end
      end

      obj.handle_state_enter(to_state)
    end

    def self.event_name(event)
      return event.name if event.respond_to?(:name)

      event.class.name
    end

    def self.event_class(event)
      event.is_a?(Class) ? event : event.class
    end

    def self.deleted_event?(event)
      event_type =
        if event.respond_to?(:event_type)
          event.event_type
        elsif event.respond_to?(:type)
          event.type
        elsif event.class.respond_to?(:event_type)
          event.class.event_type
        end

      event_type == 'deleted_event'
    end

    # @param obj [Object] instance with included StateMachine
    # @param state_name [Symbol] state name
    def self.raise_if_invalid_state(obj, state_name)
      state = obj.class.find_state(state_name)
      raise InvalidStateError.new(state: state_name) if state.nil?
    end

    def current_state
      send self.class.state_name
    end

    # State callbacks are intentionally small; event subscribers remain the
    # preferred place for broader side effects.
    def handle_state_exit(state_name)
      state = self.class.find_state(state_name)
      state[:on_exit].each { |callback| callback.call(self) }
    end

    def handle_state_enter(state_name)
      state = self.class.find_state(state_name)
      state[:on_enter].each { |callback| callback.call(self) }
    end

    module ClassMethods
      attr_reader :state_name
      attr_reader :state_machine_enabled
      attr_reader :states
      attr_reader :transitions

      # Define state attribute and enable the state machine handling
      def attr_state(name)
        attr_accessor name

        @state_name = name
        @state_machine_enabled = true
      end

      # Define state with enter and exit callbacks
      #
      # @example
      #   class Car
      #     state :initialized, exit: []
      #     state :pending, enter: []
      #   end
      #
      # @param name [Symbol] State name
      # @param options [Hash] Options
      # @option options [Array] :on_enter List of callbacks when entering
      # @option options [Array] :on_exit List of callbacks when exiting
      def state(name, options = {})
        raise 'state name is not symbol' unless name.is_a? Symbol

        options = { on_enter: [], on_exit: [] }.merge(options)

        @states ||= {}
        @states.merge!(Hash[name, options])
      end

      # Define allowed transitions
      #
      # @example
      #   class Car
      #     ...
      #     transition from: :pending, to: :approved
      #   end
      def transition(from:, to:, event:)
        raise 'transition from is not symbol' unless from.is_a? Symbol
        raise 'transition to is not symbol' unless to.is_a? Symbol
        raise 'transition event is not class' unless event.is_a? Class

        @transitions ||= []
        @transitions << { from: from, to: to, event: event }
      end

      # Find state
      #
      # @example
      #   find_state(:initialized)
      def find_state(name)
        (states || {})[name]
      end

      # Find transition
      #
      # @example
      #   find_transition(from: :initialized, to: :on_hold)
      def find_transition(values)
        (transitions || []).find do |transition|
          (values.to_a - transition.to_a).empty?
        end
      end
    end
  end
end
