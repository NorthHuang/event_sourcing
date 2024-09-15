# frozen_string_literal: true

module EventSourcing
  module Helpers # # end #   end #     do_some_logic #   on MyEvent do |event| # # class MyEventHandler < CommandHandler # Creates ability to use DSL like: ##
    module SelfApplier
      module ClassMethods
        # on do |message|
        #   ...
        # end
        def on(*message_classes, &block)
          message_classes.each do |message_class|
            message_mapping[message_class] << [block, :default]
          end
        end

        # on_with_options do |message, options|
        #   entity = options[:entity]
        #   ...
        # end
        def on_with_options(*message_classes, &block)
          if block.arity != 2
            raise ArgumentError, 'wrong number of arguments (expected 2)'
          end

          message_classes.each do |message_class|
            message_mapping[message_class] << [block, :with_options]
          end
        end

        def message_mapping
          @message_mapping ||= Hash.new { |hash, key| hash[key] = [] }
        end

        def handles_message?(message)
          message_mapping.key?(message.class)
        end
      end

      def self.included(host_class)
        host_class.extend(ClassMethods)
      end

      # @param [EventSourcing::Event] message
      # @param [NilClass, EventSourcing::AggregateRoot, EventSourcing::Domain] entity_or_nil
      # @return []
      def handle_message(message, entity_or_nil = nil)
        handlers = self.class.message_mapping[message.class] || []
        handlers.each do |handler, handler_type|
          case handler_type
          when :default
            instance_exec(message, &handler)
          when :with_options
            options = { entity: entity_or_nil }
            instance_exec(message, options, &handler)
          end
        end
      end
    end
  end
end
