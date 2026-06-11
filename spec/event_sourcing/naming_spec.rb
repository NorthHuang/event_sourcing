# frozen_string_literal: true

RSpec.describe "EventSourcing type names" do
  before do
    stub_const("ExampleApp", Module.new)
    stub_const("ExampleApp::Aggregates", Module.new)
    stub_const("ExampleApp::Events", Module.new)
    stub_const(
      "ExampleApp::Aggregates::Account",
      Class.new(EventSourcing::AggregateRoot)
    )
    stub_const(
      "ExampleApp::Events::AccountOpenedEvent",
      Class.new(EventSourcing::Event)
    )
  end

  it "derives aggregate type from the Aggregates namespace" do
    expect(ExampleApp::Aggregates::Account.aggregate_type).to eq("account")
  end

  it "derives event type from the Events namespace" do
    expect(ExampleApp::Events::AccountOpenedEvent.event_type)
      .to eq("account_opened_event")
  end
end
