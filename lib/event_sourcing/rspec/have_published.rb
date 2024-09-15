# frozen_string_literal: true

module EventSourcing
  module RSpec
    class HavePublished
      def initialize(mandatory_expected, *optional_expected, differ:, phraser:)
        @expected = [mandatory_expected, *optional_expected]
        @matcher = ::RSpec::Matchers::BuiltIn::Include.new(*expected)
        @differ = differ
        @phraser = phraser
      end

      def matches?(event_store)
        @events =
          event_store.load_events(from_version: start ? from_version : nil)
        @events = events.each
        @matcher.matches?(events) && matches_count?
      end

      def exactly(count)
        @count = count
        self
      end

      def times
        self
      end
      alias time times

      def from_version(version)
        @start = version
        self
      end

      def once
        exactly(1)
      end

      def failure_message
        "expected #{expected} to be published, diff:" +
          differ.diff_as_string(expected.to_s, events.to_a.to_s)
      end

      def failure_message_when_negated
        "expected #{expected} not to be published, diff:" +
          differ.diff_as_string(expected.to_s, events.to_a.to_s)
      end

      def description
        "have published events that have to (#{phraser.call(expected)})"
      end

      def strict
        @matcher = ::RSpec::Matchers::BuiltIn::Match.new(expected)
        self
      end

      private

      def matches_count?
        return true unless count
        raise NotSupported if expected.size > 1

        expected.all? do |event_or_matcher|
          events.select { |e| event_or_matcher === e }.size.equal?(count)
        end
      end

      attr_reader :differ, :phraser, :expected, :count, :events, :start
    end
  end
end
