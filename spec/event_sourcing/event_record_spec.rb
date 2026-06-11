# frozen_string_literal: true

RSpec.describe EventSourcing::EventRecord do
  before(:all) do
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    ActiveRecord::Schema.define do
      create_table :account_events, force: true do |t|
        t.string :parent_id
        t.string :aggregate_id, null: false
        t.integer :version, null: false
        t.string :event_type, null: false
        t.json :event_payload, null: false, default: {}
        t.string :domain_type
        t.string :domain_id
        t.datetime :created_at, null: false
      end
    end
  end

  before do
    stub_const("ExampleApp", Module.new)
    stub_const("ExampleApp::Events", Module.new)
    stub_const(
      "ExampleApp::Events::AccountOpenedEvent",
      Class.new(EventSourcing::Event) do
        attrs :account_name, String
      end
    )
    stub_const(
      "AccountEvent",
      Class.new(described_class) do
        self.table_name = "account_events"
        self.event_module = "ExampleApp::Events"

        def self.save_event(event)
          create!(event: event)
        end
      end
    )

    AccountEvent.delete_all
  end

  it "serializes and deserializes event records" do
    event =
      ExampleApp::Events::AccountOpenedEvent.new(
        parent_id: "parent-1",
        aggregate_id: "aggregate-1",
        version: 1,
        account_name: "Operating Account"
      )

    record = AccountEvent.save_event(event)

    expect(record.event).to be_a(ExampleApp::Events::AccountOpenedEvent)
    expect(record.event.account_name).to eq("Operating Account")
  end

  it "stores and loads events through the event store" do
    configuration = EventSourcing::Configuration.new
    configuration.event_record_class = AccountEvent
    event =
      ExampleApp::Events::AccountOpenedEvent.new(
        aggregate_id: "aggregate-1",
        version: 1,
        account_name: "Operating Account"
      )

    configuration.event_store.store_events([event])

    expect(
      configuration.event_store.load_events(aggregate_id: "aggregate-1")
    ).to contain_exactly(
      an_event(ExampleApp::Events::AccountOpenedEvent).with_data(
        account_name: "Operating Account"
      )
    )
  end
end
