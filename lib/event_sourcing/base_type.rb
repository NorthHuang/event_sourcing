# frozen_string_literal: true

module EventSourcing
  class BaseType
    class UnsupportedType < StandardError
      def initialize(host, attr_name, value, type)
        @host = host
        @attr_name = attr_name
        @type = type
        @value = value
        super(message)
      end

      def message
        "[#{@host.class}] attr_name: #{@attr_name}, type: #{@type}, value: #{
          @value
        }"
      end
    end

    class ValidationError < StandardError
      def initialize(host, attr_name, expected_type, type)
        @host = host
        @attr_name = attr_name
        @expected_type = expected_type
        @type = type
        super(message)
      end

      def message
        "[#{@host.class}] attr_name: #{@attr_name}, expected_type: #{
          @expected_type
        }, type: #{@type}"
      end
    end

    class << self
      def field(name, type, options = {})
        @fields ||= {}
        @fields[name] = [type, options]
      end

      def fields
        @fields || {}
      end
    end
  end
end
