# Changelog

## Unreleased

- Require Ruby 3.2 or newer.
- Remove runtime RSpec dependency from the main `event_sourcing` require path.
- Add `event_sourcing/rspec` as the explicit entrypoint for test matchers.
- Replace application-specific errors and direct error reporter calls with
  generic configuration hooks.
- Add `event_record_class`, `uncommitted_events`, and `committed` as the
  preferred public API names while retaining backward-compatible aliases.
- Rewrite the README with open-source installation and integration guidance.
