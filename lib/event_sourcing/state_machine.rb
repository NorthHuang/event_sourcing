# frozen_string_literal: true

# State Machine for assets
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
#     transitions from: :initialized, to: :pending, event: Events::StartedEvent
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

    # Listen to the state change and execute the livecycle hooks
    #
    # @param obj [Object] instance with included StateMachine
    # @param event [Object] event klass same as transition[:event]
    def self.listen(obj, event)
      unless obj.class.state_machine_enabled
        yield
        return
      end # Useful for handling different behavior on assets v1 and v2

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

      unless event.event_type == 'deleted_event'
        transition =
          obj.class.find_transition(
            from: from_state, to: to_state, event: event
          )
        if transition.nil?
          raise InvalidTransitionError.new(
            from: from_state, to: to_state, event: event.name
          )
        end
      end

      obj.handle_state_enter(to_state)
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

    # TODO: still did not define the usage of on_exit and on_enter
    #   since the event subscriber can also handle same functionality
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
      # @option options [Array] :enter List of callbacks when enter
      # @option options [Array] :leave List of callbacks when leave
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
      #     transitions from: :pending, to: :approved
      #   end
      def transition(from:, to:, event:)
        raise 'transitions from is not symbol' unless from.is_a? Symbol
        raise 'transitions to is not symbol' unless to.is_a? Symbol
        raise 'event to is not class' unless event.is_a? Class

        @transitions ||= []
        @transitions << { from: from, to: to, event: event }
      end

      # Find state
      #
      # @example
      #   find_state(:initialized)
      def find_state(name)
        states[name]
      end

      # Find transition
      #
      # @example
      #   find_transition(from: :initialized, to: :on_hold)
      def find_transition(values)
        transitions.find { |transition| (values.to_a - transition.to_a).empty? }
      end
    end
  end
end
