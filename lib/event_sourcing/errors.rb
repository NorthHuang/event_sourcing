# frozen_string_literal: true

module EventSourcing
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class DomainNotFoundError < Error
    attr_reader :aggregate_id, :domain_id, :domain_type

    def initialize(aggregate_id: nil, domain_id: nil, domain_type: nil)
      @aggregate_id = aggregate_id
      @domain_id = domain_id
      @domain_type = domain_type

      super(
        "domain not found" \
        " aggregate_id=#{aggregate_id.inspect}" \
        " domain_type=#{domain_type.inspect}" \
        " domain_id=#{domain_id.inspect}"
      )
    end
  end
end
