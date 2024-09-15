# frozen_string_literal: true

module EventSourcing
  class CommandNotValidError < StandardError
    attr_reader :command
    def initialize(command)
      @command = command
    end

    def message
      @command.errors.full_messages.join(',')
    end

    def errors
      @command.errors
    end
  end

  class CommandHandler
    include Helpers::SelfApplier
    include AfterCommit::Helper

    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    def repository
      @configuration.aggregate_repository
    end

    def side_effect_enabled?
      @configuration.side_effect_enabled
    end

    def write_event_only?
      @configuration.write_event_only
    end

    def handle(cmd)
      cmd.validate_types!

      raise CommandNotValidError.new(cmd) if cmd.invalid?
      handle_message(cmd)
    end
  end
end
