# frozen_string_literal: true

require_relative 'command'

module EventSourcing
  class << self
    def configuration
      Configuration.instance
    end

    def configure
      yield configuration if block_given?
      configuration
    end

    def reset_configuration!
      Configuration.reset
    end
  end
end
