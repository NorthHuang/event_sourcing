# frozen_string_literal: true

RSpec.describe EventSourcing::Domain do
  describe "#id" do
    it "returns the domain id" do
      domain = described_class.new(
        EventSourcing::Configuration.new,
        "aggregate-1",
        "domain-1"
      )

      expect(domain.id).to eq("domain-1")
    end
  end
end
