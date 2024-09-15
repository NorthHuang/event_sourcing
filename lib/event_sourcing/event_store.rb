# frozen_string_literal: true

module EventSourcing
  class EventStore
    def initialize(configuration)
      @configuration = configuration
    end

    def commit_events(events, entity_or_nil = nil)
      store_events(events, entity_or_nil)
    end

    def store_events(events, entity_or_nil = nil)
      events.each { |event| assets_event_class.save_event(event) }
      publish_events(events, entity_or_nil)
    end

    ##
    # Returns all events for the aggregate ordered by version
    def load_events(
      parent_id: nil,
      aggregate_id: nil,
      domain_type: nil,
      domain_id: nil,
      until_version: nil,
      from_version: nil,
      until_created_at: nil
    )
      records = []
      query = assets_event_class.order(version: :asc)
      query = query.where(parent_id: parent_id) if parent_id
      query = query.where(aggregate_id: aggregate_id) if aggregate_id
      if domain_type
        query = query.where(domain_type: domain_type, domain_id: domain_id)
      end
      query = query.where('version <= ?', until_version) if until_version
      query = query.where('version > ?', from_version) if from_version
      if until_created_at
        query = query.where('created_at <= ?', until_created_at)
      end
      records.push(*query).map(&:event)
    end

    ##
    # Return events from multiple aggregates
    # aggregate_selectors are expected to be in the format of [ { aggregate_id: <uuid>, from_version: <version> } ]
    def load_multi_aggregate_events(
      parent_id: nil,
      aggregate_selectors: [],
      domain_type: nil,
      domain_id: nil,
      until_version: nil,
      until_created_at: nil
    )
      records = []
      query = assets_event_class.order(version: :asc)
      query = query.where(parent_id: parent_id) if parent_id

      if domain_type
        query = query.where(domain_type: domain_type, domain_id: domain_id)
      end
      query = query.where('version <= ?', until_version) if until_version

      if until_created_at
        query = query.where('created_at <= ?', until_created_at)
      end

      # Arel is utilized to allow custom parenthesis setup to allow structure of
      # WHERE <generic conditions> AND ((<aggregate specific cond>) OR (<aggregate specific cond>) OR ...)
      arel_table = assets_event_class.arel_table

      aggregate_queries =
        arel_table.grouping(
          aggregate_selectors.map do |aggregate_selector|
            aggregate_id, from_version =
              aggregate_selector.values_at(:aggregate_id, :from_version)

            next if aggregate_id.blank? && from_version.blank?

            aggregate_query = arel_table[:aggregate_id].eq(aggregate_id)

            aggregate_query =
              aggregate_query.and(
                arel_table[:version].gt(from_version)
              ) if from_version

            arel_table.grouping(aggregate_query)
          end.reduce { |s, x| Arel::Nodes::Or.new(s, x) }
        )

      query = query.where(aggregate_queries)

      records.push(*query).map(&:event)
    end

    def replay_events_from_cursor(batch_size: 100, get_events:)
      cursor = get_events.call
      cursor.find_each(batch_size: batch_size) do |event|
        publish_events([event])
      end
    end

    private

    def publish_events(events, entity_or_nil = nil)
      event_publisher.publish_events(events, entity_or_nil)
    end

    def event_publisher
      @configuration.event_publisher
    end

    def assets_event_class
      @configuration.assets_event_class
    end
  end
end
