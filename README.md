# event_sourcing

A small event sourcing toolkit for Ruby 3.2+ applications that use
ActiveRecord.

It provides:

- command and command-handler dispatch
- aggregate roots and nested domains
- event records backed by ActiveRecord
- event replay and projection hooks
- optional snapshots
- optional request-local aggregate memoization
- optional RSpec matchers

This gem does not own your database schema or application namespaces. The host
application provides the event record model, event table, snapshot table if
needed, command handlers, and event handlers.

## Installation

Add the gem to your application:

```ruby
gem "event_sourcing"
```

The runtime gem does not load RSpec. Test helpers are loaded separately with:

```ruby
require "event_sourcing/rspec"
```

## Configuration

Configure the gem from an initializer:

```ruby
EventSourcing.configure do |config|
  config.event_record_class = AccountEvent
  config.command_handlers = [
    Accounts::CommandHandlers::OpenAccountHandler.new(config)
  ]
  config.event_handlers = [
    Accounts::Projectors::AccountProjector.new(config)
  ]

  config.error_reporter = lambda do |error, context|
    Rails.logger.error("[event_sourcing] #{error.class}: #{error.message}")
    Rails.logger.debug(context.inspect)
  end
end
```

Optional settings:

```ruby
EventSourcing.configure do |config|
  config.snapshot_enabled = true
  config.snapshot_class = AccountSnapshot
  config.memoization_store = EventSourcing::MemoizationStore::RequestStore
  config.silent_exception_reraise_errors = [ExpectedBusinessError]
end
```

`error_reporter` can be any object that responds to `call(error, context)` or
`notify(error)`.

## Event Record

Create an ActiveRecord model that inherits from `EventSourcing::EventRecord`.
The host application decides the table name and persistence behavior.

```ruby
class AccountEvent < EventSourcing::EventRecord
  self.table_name = "account_events"
  self.event_module = "Accounts::Events"

  def self.save_event(event)
    create!(event: event)
  end
end
```

A typical PostgreSQL event table contains:

```ruby
create_table :account_events do |t|
  t.string :parent_id
  t.string :aggregate_id, null: false
  t.integer :version, null: false
  t.string :event_type, null: false
  t.jsonb :event_payload, null: false, default: {}
  t.string :domain_type
  t.string :domain_id
  t.datetime :created_at, null: false
end

add_index :account_events, [:aggregate_id, :version]
add_index :account_events, [:domain_type, :domain_id]
```

## Events

Events inherit from `EventSourcing::Event` and declare typed attributes with
`attrs`.

```ruby
module Accounts
  module Events
    class AccountOpenedEvent < EventSourcing::Event
      attrs :account_name, String
      attrs :opened_by, String
    end
  end
end
```

Event classes under an `Events` namespace are stored without the application
prefix. For example, `Accounts::Events::AccountOpenedEvent` becomes
`account_opened_event`.

## Aggregates

Aggregates inherit from `EventSourcing::AggregateRoot`. Public behavior emits
events with `apply`; event handlers mutate aggregate state through the `on`
DSL.

```ruby
module Accounts
  module Aggregates
    class Account < EventSourcing::AggregateRoot
      SCHEMA_VERSION = 1

      attr_reader :account_name

      on Events::AccountOpenedEvent do |event|
        @account_name = event.account_name
      end

      def open(account_name:, opened_by:)
        apply Events::AccountOpenedEvent,
              account_name: account_name,
              opened_by: opened_by
      end
    end
  end
end
```

Load and commit aggregates through the repository:

```ruby
repository = EventSourcing.configuration.aggregate_repository

account = repository.load_aggregate(
  Accounts::Aggregates::Account,
  account_id
)
account.open(account_name: "Operating Account", opened_by: user_id)
repository.commit(account)
```

## State Machines

Aggregates and domains can declare simple state transitions. When state-machine
support is enabled with `attr_state`, each applied event must move the object
through a declared transition.

```ruby
class Account < EventSourcing::AggregateRoot
  attr_state :status

  state :initialized
  state :opened
  transition(
    from: :initialized,
    to: :opened,
    event: Accounts::Events::AccountOpenedEvent
  )
end
```

## Commands

Commands use typed attributes and ActiveModel validations.

```ruby
module Accounts
  module Commands
    class OpenAccount < EventSourcing::Command
      attrs :account_id, String
      attrs :account_name, String
      attrs :opened_by, String

      validates :account_id, :account_name, :opened_by, presence: true
    end
  end
end
```

Handlers inherit from `EventSourcing::CommandHandler`.

```ruby
module Accounts
  module CommandHandlers
    class OpenAccountHandler < EventSourcing::CommandHandler
      on Commands::OpenAccount do |command|
        account = repository.load_aggregate(
          Aggregates::Account,
          command.account_id
        )
        account.open(
          account_name: command.account_name,
          opened_by: command.opened_by
        )
        repository.commit(account)
      end
    end
  end
end
```

Execute commands with:

```ruby
EventSourcing.configuration.command_service.execute(command)
```

## Event Handlers And Projectors

Event handlers receive events after they are stored.

```ruby
module Accounts
  module Projectors
    class AccountProjector < EventSourcing::EventHandler
      on Accounts::Events::AccountOpenedEvent do |event|
        AccountReadModel.create!(
          account_id: event.aggregate_id,
          account_name: event.account_name
        )
      end
    end
  end
end
```

For replayable projectors, inherit from `EventSourcing::Projector` and implement
`remove(aggregate_id)`.

## Snapshots

Set `config.snapshot_enabled = true` and provide `config.snapshot_class` to
enable snapshots. Snapshot records are expected to support:

- `parent_id`
- `aggregate_id`
- `aggregate_type`
- `event_version`
- `schema_version`
- `data`
- `created_at`

Snapshots currently use `Marshal.dump` and `Marshal.load`. Only load snapshots
that were written by your own trusted application.

## RSpec Matchers

RSpec is not a runtime dependency. Add it to your application's test or
development dependencies before loading the matcher entrypoint.

Load matchers only in the test environment:

```ruby
require "event_sourcing/rspec"
```

Available matchers:

- `be_event`, `be_an_event`, `an_event`, `event`
- `have_published`
- `publish`
- `have_applied`
- `apply`

Example:

```ruby
expect(event_store).to have_published(
  an_event(Accounts::Events::AccountOpenedEvent).with_data(
    aggregate_id: account_id,
    account_name: "Operating Account"
  )
)
```

## Compatibility Notes

The public API uses `event_record_class`, `uncommitted_events`, `committed`, and
`event_sourcing/extensions`.

For existing applications, the previous names still work:

- `assets_event_class`
- `uncommited_events`
- `commited`
- `event_sourcing/extentions`

These compatibility aliases are kept to ease migration, but new code should use
the corrected names.

## Development

This project targets Ruby 3.2 and uses GitHub Actions for CI. Useful local
checks are:

```sh
bundle install
bundle exec rspec
gem build event_sourcing.gemspec
ruby -Ilib -e 'require "event_sourcing"; require "event_sourcing/rspec"'
```

## License

MIT.
