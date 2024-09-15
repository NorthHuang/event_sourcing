# event_sourcing
## RSpec Matchers

Reference to: [RailsEventStore-RSpec](https://github.com/RailsEventStore/rails_event_store/tree/master/rails_event_store-rspec)

This part of document is also copied from [RailsEventStore-RSpec](https://github.com/RailsEventStore/rails_event_store/tree/master/rails_event_store-rspec) README.md and modified.

But have modified, some functions from rails_event_store-rspec were not included. Especially `stream` related.

### be_event

The `be_event` matcher enables you to make expectations on a domain event. It exposes fluent interface.

```ruby
let(:run_test) { Accounts::Service.new.create }

run_test

event = AccountEvent.first

expect(event).to be_an_event(Accounts::Events::AccountCreatedEvent)
```

By default the behaviour of `with_data` is not strict, that is the expectation is met when all specified values for keys match. Additional data that is not specified to be expected does not change the outcome.

In `with_data`, in our event_sourcing module, we default every events to have `aggregate_id`, `parent_id`, `version`, and other attributes that we defined in the event_type class.

*noted: originally in rails_event_store, they have a `with_metadata`, but the structure of our event is different with rails_event_store, we only got `with_data`.*

```ruby
let(:run_test) { Accounts::Service.new.create }

run_test

event = AccountEvent.first

expect(event).to be_an_event(Accounts::Events::AccountCreatedEvent).with_data(
  parent_id: owner.id,
  aggregate_id: account_id,
  account_name: account_name,
  email: email,
  created_by: user.id
)
```

You may have noticed the same matcher being referenced as `be_event`, `be_an_event` and `an_event`. There's also just `event`. Use whichever reads better grammatically.

### have_published

Use this matcher to target `event_store`.
Its behaviour can be best compared to the `include` matcher — it is satisfied by at least one element present in the collection. You're encouraged to compose it with `be_event`.

```ruby
subject(:service) { Accounts::Service.new }
let(:event_store) { Accounts.aggregate_repository.event_store }
let(:run_test) { service.update }

run_test
expect(event_store).to have_published(
  an_event(Accounts::Events::AccountUpdatedEvent).with_data(
    parent_id: owner.id,
    aggregate_id: account_id,
    version: 2,
    account_name: new_account_name,
    email: new_email
  )
)
```

It is sometimes important to ensure no additional events have been published. Luckliy there's a modifier to cover that usecase.

```ruby
expect(event_store).not_to have_published(an_event(Accounts::Events::AccountCreatedEvent)).once
expect(event_store).to have_published(an_event(Accounts::Events::AccountUpdatedEvent)).exactly(2).times
```

Finally you can make expectation on several events at once.

```ruby
subject(:service) { Accounts::Service.new }
let(:event_store) { Accounts.aggregate_repository.event_store }
let(:run_test) { service.update }
before { service.create }

run_test
expect(event_store).to have_published(
  an_event(Accounts::Events::AccountCreatedEvent),
  an_event(Accounts::Events::AccountUpdatedEvent).with_data(
    parent_id: owner.id,
    aggregate_id: account_id,
    version: 2,
    account_name: new_account_name,
    email: new_email
  )
)
```

### publish

This matcher is similar to `have_published` one, but targets only events published in given execution block.

```ruby
subject(:service) { Accounts::Service.new }
let(:event_store) { Accounts.aggregate_repository.event_store }
let(:run_test) { service.update }
before { service.create }

expect { run_test }.to publish(
  an_event(Accounts::Events::AccountUpdatedEvent)
).in(event_store)
```

### Aggregate Root Matcher
### have_applied

This matcher is intended to be used on [aggregate root](https://github.com/RailsEventStore/rails_event_store/tree/master/aggregate_root#usage). Behaviour is almost identical to `have_published` counterpart. Expecations are made against internal applied events collection.


```ruby
subject(:service) { Accounts::Service.new }
let(:aggregate_root) do
  Accounts.aggregate_repository.load_aggregate(
    Accounts::Aggregates::Account,
    account_id,
    parent_id: owner.id
  )
end
let(:run_test) { service.update }
before { service.create }

run_test
expect(aggregate_root).to have_applied(
  an_event(Accounts::Events::AccountCreatedEvent),
  an_event(Accounts::Events::AccountUpdatedEvent).with_data(
    parent_id: owner.id,
    aggregate_id: account_id,
    version: 2,
    account_name: new_account_name,
    email: new_email
  )
)
```

### apply

This matcher is similar to `have_applied`. It check if expected event is applied in given `aggregate_root` object but only during execution of code block.

```ruby
subject(:service) { Accounts::Service.new }
let(:aggregate_root) do
  Accounts.aggregate_repository.load_aggregate(
    Accounts::Aggregates::Account,
    account_id,
    parent_id: owner.id
  )
end
let(:run_test) { service.update }
before { service.create }

expect { run_test }.to apply(an_event(Accounts::Events::AccountUpdatedEvent)).in(aggregate_root)
```