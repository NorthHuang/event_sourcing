# frozen_string_literal: true

module EventSourcing
  class AggregateRepository
    MEMOIZATION_KEY_VERSION = 1

    def initialize(configuration)
      @configuration = configuration
    end

    # load_aggregate - Load aggregate root
    def load_aggregate(
      klass,
      aggregate_id,
      parent_id: nil,
      until_version: nil,
      until_created_at: nil,
      with_snapshot: true,
      use_event_loader: false,
      **extra_options
    )
      load_options =
        AggregateLoadOptions.new(
          parent_id: parent_id,
          aggregate_id: aggregate_id,
          until_version: until_version,
          until_created_at: until_created_at,
          with_snapshot: with_snapshot,
          extra_options: extra_options
        )

      unless use_event_loader
        if @configuration.aggregate_loader.present?
          aggregate = @configuration.aggregate_loader.call(load_options)
          if aggregate
            aggregate.configuration = @configuration
            return aggregate
          end
        end
      end

      # load from memory if possible in order to reduce DB load
      if memoization_store.present?
        memoized_aggregate =
          memoization_store.read(
            memoization_key(klass, aggregate_id, load_options)
          )

        return memoized_aggregate if memoized_aggregate.present?
      end

      snapshot =
        if snapshot_enabled? && with_snapshot
          query =
            snapshot_class
              .where(
                aggregate_id: aggregate_id,
                aggregate_type: klass.aggregate_type,
                schema_version: klass::SCHEMA_VERSION
              )
              .merge(snapshot_query_by_options(load_options))
          query.order(event_version: :desc).first
        end

      aggregate =
        build_aggregate_from_snapshot(klass, snapshot, aggregate_id, parent_id)

      events =
        event_store.load_events(
          parent_id: parent_id,
          aggregate_id: aggregate_id,
          from_version: aggregate.version,
          until_version: until_version,
          until_created_at: until_created_at
        )
      aggregate.load_from_history(events)
    end

    # can take a bunch of aggregate_ids, but other arguments must be identical across aggregates
    def preload_aggregates(
      klass,
      aggregate_ids,
      parent_id: nil,
      until_version: nil,
      until_created_at: nil,
      with_snapshot: true
    )
      load_options =
        AggregateLoadOptions.new(
          parent_id: parent_id,
          until_version: until_version,
          until_created_at: until_created_at,
          with_snapshot: with_snapshot
        )

      if snapshot_enabled? && with_snapshot
        query =
          snapshot_class
            .where(
              aggregate_id: aggregate_ids,
              aggregate_type: klass.aggregate_type,
              schema_version: klass::SCHEMA_VERSION
            )
            .merge(snapshot_query_by_options(load_options))

        snapshot_ids = query.group(:aggregate_id).maximum(:id).values

        snapshot_lookup =
          snapshot_class
            .where(id: snapshot_ids)
            .index_by(&:aggregate_id) if snapshot_ids.present?
      end

      aggregates =
        aggregate_ids.map do |aggregate_id|
          snapshot = snapshot_lookup[aggregate_id] if snapshot_lookup.present?

          build_aggregate_from_snapshot(
            klass,
            snapshot,
            aggregate_id,
            parent_id
          )
        end

      # load all events from difference aggregates
      # since each aggregate might have snapshots at different versions, the from_version need to be aggregate-specific
      # other selectors like parent_id would be shared
      event_lookup =
        event_store
          .load_multi_aggregate_events(
            parent_id: parent_id,
            until_version: until_version,
            until_created_at: until_created_at,
            aggregate_selectors:
              aggregates.map do |aggregate|
                { aggregate_id: aggregate.id, from_version: aggregate.version }
              end
          )
          .group_by(&:aggregate_id)

      aggregates.each do |aggregate|
        aggregate.load_from_history(event_lookup[aggregate.id] || [])

        # agg stored for reuse if later load_aggregate is called with identical args
        if memoization_store.present?
          memoization_store.write(
            memoization_key(klass, aggregate.aggregate_id, load_options),
            aggregate
          )
        end
      end

      aggregates
    end

    def load_domain(
      klass,
      domain_id,
      parent_id: nil,
      aggregate_id: nil,
      until_version: nil,
      until_created_at: nil,
      **extra_options
    )
      if (not klass.domain_type.nil?) && domain_id.nil?
        raise 'missing domain id'
      end
      load_options =
        DomainLoadOptions.new(
          parent_id: parent_id,
          aggregate_id: aggregate_id,
          domain_type: klass.domain_type,
          domain_id: domain_id,
          until_version: until_version,
          until_created_at: until_created_at,
          extra_options: extra_options
        )
      if @configuration.domain_loaders.present? && klass.domain_type.present?
        loader = @configuration.domain_loaders[klass.domain_type]
        if loader
          domain = loader.call(load_options)
          # `domain_loader` can return nil to use the default event loader.
          return domain if domain
        end
      end

      events =
        event_store.load_events(
          parent_id: parent_id,
          aggregate_id: aggregate_id,
          domain_type: klass.domain_type,
          domain_id: domain_id,
          until_version: until_version,
          until_created_at: until_created_at
        )

      if events.empty?
        raise Assets::DomainNotExistsError if aggregate_id.nil?
        klass.new(@configuration, aggregate_id, domain_id, parent_id: parent_id)
      else
        klass.load_from_history(@configuration, events)
      end
    end

    def commit(entity)
      # entity can be a aggregate or domain
      event_store.store_events(entity.uncommited_events, entity)
      entity.commited

      if snapshot_enabled?
        aggregate =
          entity.is_a?(EventSourcing::AggregateRoot) ? entity : entity.root
        if aggregate.snapshot_takeable?
          take_snapshot!(aggregate)
        end
      end
    end

    def take_snapshot!(aggregate)
      aggregate.snapshot = snapshot_class.create!(
        parent_id: aggregate.parent_id,
        aggregate_id: aggregate.id,
        aggregate_type: aggregate.class.aggregate_type,
        event_version: aggregate.version,
        schema_version: aggregate.class::SCHEMA_VERSION,
        data: Base64.encode64(Marshal.dump(aggregate))
      )
    end

    def event_store
      @configuration.event_store
    end

    def memoization_store
      @configuration.memoization_store
    end

    private

    def memoization_key(klass, aggregate_id, load_options)
      keys = [
        klass.name,
        aggregate_id,
        load_options.memoization_key,
        MEMOIZATION_KEY_VERSION
      ]

      keys << klass::SCHEMA_VERSION if snapshot_enabled?

      keys.map(&:to_s).join(':')
    end

    def snapshot_enabled?
      @configuration.snapshot_enabled
    end

    def snapshot_class
      @configuration.snapshot_class
    end

    def build_aggregate_from_snapshot(klass, snapshot, aggregate_id, parent_id)
      aggregate =
        if snapshot
          Marshal.load(Base64.decode64(snapshot.data))
        else
          klass.new(aggregate_id, parent_id: parent_id)
        end
      aggregate.configuration = @configuration
      aggregate.snapshot = snapshot unless snapshot.nil?

      aggregate
    end

    def snapshot_query_by_options(load_options)
      query = snapshot_class.all
      query = query.where(parent_id: load_options.parent_id) if load_options
                                                                  .parent_id
      if load_options.until_version
        query = query.where('event_version <= ?', load_options.until_version)
      end
      if load_options.until_created_at
        query = query.where('created_at <= ?', load_options.until_created_at)
      end

      query
    end
  end
end
