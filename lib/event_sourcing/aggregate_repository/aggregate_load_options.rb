# frozen_string_literal: true

module EventSourcing
  class AggregateRepository
    AggregateLoadOptions =
      Struct.new(
        :parent_id,
        :aggregate_id,
        :until_version,
        :until_created_at,
        :with_snapshot,
        :extra_options,
        keyword_init: true
      ) do
        def memoization_key
          [parent_id, until_version, until_created_at, with_snapshot].join(':')
        end
      end
  end
end
