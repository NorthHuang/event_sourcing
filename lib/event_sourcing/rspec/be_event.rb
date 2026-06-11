# frozen_string_literal: true

module EventSourcing
  module RSpec
    class BeEvent
      class KindMatcher
        def initialize(expected)
          @expected = expected
        end

        def matches?(actual)
          @expected === actual
        end
      end

      class DataMatcher
        def initialize(expected, strict:)
          @strict = strict
          @expected = expected
        end

        def matches?(actual)
          return true unless @expected
          matcher =
            if @strict
              ::RSpec::Matchers::BuiltIn::Match
            else
              ::RSpec::Matchers::BuiltIn::Include
            end
          matcher.new(@expected).matches?(actual)
        end
      end

      class FailureMessage
        class ExpectedLine
          def initialize(expected_klass, expected_data)
            @expected_klass = expected_klass
            @expected_data = expected_data
          end

          def to_s
            ["\nexpected: ", @expected_klass, with, data]
          end

          private

          def with
            ' with' if [@expected_data].any?
          end

          def data
            [' data: ', @expected_data] if @expected_data
          end
        end

        class ActualLine
          def initialize(actual_klass, actual_data, expected_data)
            @actual_klass = actual_klass
            @actual_data = actual_data
            @expected_data = expected_data
          end

          def to_s
            ["\n     got: ", @actual_klass, with, data, "\n"]
          end

          private

          def with
            ' with' if [@expected_data].any?
          end

          def data
            [' data: ', @actual_data] if @expected_data
          end
        end

        class Diff
          def initialize(actual, expected, label, differ:)
            @actual = actual
            @expected = expected
            @label = label
            @differ = differ
          end

          def to_s
            @expected &&
              [
                "\n#{@label} diff:",
                @differ.diff_as_string(@actual.to_s, @expected.to_s)
              ]
          end
        end

        def initialize(
          expected_klass, actual_klass, expected_data, actual_data, differ:
        )
          @expected_klass = expected_klass
          @actual_klass = actual_klass
          @expected_data = expected_data
          @actual_data = actual_data
          @differ = differ
        end

        def to_s
          [
            ExpectedLine.new(@expected_klass, @expected_data),
            ActualLine.new(@actual_klass, @actual_data, @expected_data),
            Diff.new(@actual_data, @expected_data, 'Data', differ: @differ)
          ].map(&:to_s).join
        end
      end

      include ::RSpec::Matchers::Composable

      def initialize(expected, differ:, formatter:)
        @expected = expected
        @differ = differ
        @formatter = formatter
      end

      def matches?(actual)
        @actual = actual
        matches_kind && matches_data
      end

      def with_data(expected_data)
        @expected_data = expected_data
        self
      end

      def failure_message
        FailureMessage.new(
          expected_event_type,
          actual_event_type,
          expected_data,
          actual_event_data,
          differ: differ
        ).to_s
      end

      def failure_message_when_negated
        "
expected: not a kind of #{expected}
     got: #{actual.class}
"
      end

      def strict
        @strict = true
        self
      end

      def description
        "be an event #{formatter.call(expected)}#{
          data_expectations_description
        }"
      end

      def data_expectations_description
        predicate = strict? ? 'matching' : 'including'
        expectation_list = []
        if expected_data
          expectation_list <<
            "with data #{predicate} #{formatter.call(expected_data)}"
        end
        " (#{expectation_list.join(' and ')})" if expectation_list.any?
      end

      private

      def expected_event_type
        expected.try(:event_type) || expected.try(:type)
      end

      def actual_event_type
        actual.try(:event_type) || actual.try(:type)
      end

      def matches_kind
        KindMatcher.new(expected_event_type).matches?(actual_event_type)
      end

      def matches_data
        DataMatcher.new(expected_data, strict: strict?).matches?(
          actual_event_data
        )
      end

      def actual_event_data
        if actual.is_a? EventSourcing::Event
          actual.instance_values.with_indifferent_access 
        elsif actual.is_a? EventSourcing::EventRecord
          actual.slice([:parent_id, :aggregate_id, :version]).merge(actual.event_payload).with_indifferent_access
        end
      end

      attr_reader :expected_data, :actual, :expected, :differ, :formatter

      def strict?
        @strict
      end
    end
  end
end
