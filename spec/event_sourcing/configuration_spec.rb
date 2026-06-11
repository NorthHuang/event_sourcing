# frozen_string_literal: true

RSpec.describe EventSourcing::Configuration do
  subject(:configuration) { described_class.new }

  describe "#event_record_class" do
    it "stores the configured event record class" do
      configuration.event_record_class = String

      expect(configuration.event_record_class).to eq(String)
    end

    it "keeps assets_event_class as a backward-compatible alias" do
      configuration.assets_event_class = String

      expect(configuration.event_record_class).to eq(String)
    end
  end

  describe "#report_error" do
    it "sends the error and context to callable reporters" do
      reported = nil
      configuration.error_reporter = lambda do |error, context|
        reported = [error, context]
      end

      error = StandardError.new("boom")
      configuration.report_error(error, context: { operation: "example" })

      expect(reported).to eq([error, { operation: "example" }])
    end
  end
end
