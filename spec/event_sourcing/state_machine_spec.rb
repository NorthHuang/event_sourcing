# frozen_string_literal: true

RSpec.describe EventSourcing::StateMachine do
  before do
    stub_const("ExampleApp", Module.new)
    stub_const("ExampleApp::Events", Module.new)
    stub_const(
      "ExampleApp::Events::DeletedEvent",
      Class.new(EventSourcing::Event)
    )
    stub_const(
      "ExampleApp::Events::CreatedEvent",
      Class.new(EventSourcing::Event)
    )
    stub_const(
      "ExampleApp::ExampleAggregate",
      Class.new do
        include EventSourcing::StateMachine

        attr_state :status
        state :initialized
        state :created
        transition(
          from: :initialized,
          to: :created,
          event: ExampleApp::Events::CreatedEvent
        )

        def initialize
          @status = :initialized
        end
      end
    )
  end

  describe ".deleted_event?" do
    it "recognizes deleted event classes" do
      expect(described_class.deleted_event?(ExampleApp::Events::DeletedEvent))
        .to be(true)
    end

    it "recognizes deleted event instances" do
      event =
        ExampleApp::Events::DeletedEvent.new(
          aggregate_id: "aggregate-1",
          version: 1
        )

      expect(described_class.deleted_event?(event)).to be(true)
    end

    it "rejects other event classes" do
      expect(described_class.deleted_event?(ExampleApp::Events::CreatedEvent))
        .to be(false)
    end
  end

  describe ".listen" do
    it "matches transitions when the event is a class" do
      aggregate = ExampleApp::ExampleAggregate.new

      described_class.listen(aggregate, ExampleApp::Events::CreatedEvent) do
        aggregate.status = :created
      end

      expect(aggregate.status).to eq(:created)
    end

    it "matches transitions when the event is an instance" do
      aggregate = ExampleApp::ExampleAggregate.new
      event =
        ExampleApp::Events::CreatedEvent.new(
          aggregate_id: "aggregate-1",
          version: 1
        )

      described_class.listen(aggregate, event) do
        aggregate.status = :created
      end

      expect(aggregate.status).to eq(:created)
    end
  end
end
