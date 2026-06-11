# frozen_string_literal: true

RSpec.describe EventSourcing do
  after do
    described_class.reset_configuration!
  end

  describe ".configure" do
    it "yields and returns the singleton configuration" do
      configuration =
        described_class.configure do |config|
          config.event_record_class = String
        end

      expect(configuration.event_record_class).to eq(String)
    end
  end
end
