# frozen_string_literal: true

RSpec.describe EventSourcing::AggregateRoot do
  describe "#id" do
    it "returns the aggregate id" do
      aggregate = described_class.new("aggregate-1")

      expect(aggregate.id).to eq("aggregate-1")
    end
  end
end
