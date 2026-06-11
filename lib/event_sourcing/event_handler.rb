# frozen_string_literal: true

module EventSourcing
  class EventHandler
    include Helpers::SelfApplier
    include AfterCommit::Helper

    def initialize(configuration)
      @configuration = configuration
    end
  end
end
