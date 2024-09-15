# frozen_string_literal: true

module EventSourcing
  class AggregateRepository
    DomainLoadOptions =
      Struct.new(
        :parent_id,
        :aggregate_id,
        :domain_type,
        :domain_id,
        :until_version,
        :until_created_at,
        :extra_options,
        keyword_init: true
      )
  end
end
