# frozen_string_literal: true

module EventSourcing
  class SilentExecuteError < StandardError
    def initialize(error)
      @error = error
    end

    def message
      @error.message
    end

    def bugsnag_meta_data
      { assets_v2: @error.try(:metadata) }
    end

    def backtrace
      @error.try(:backtrace)
    end
  end

  class CommandService
    def initialize(
      configuration, silent_exception: false, skip_execution: false
    )
      @configuration = configuration
      @silent_exception = silent_exception
      @skip_execution = skip_execution
    end

    def execute(command)
      return if @skip_execution
      if @silent_exception
        silent_execute { run_handles(command) }
      else
        run_handles(command)
      end
    end

    private

    def silent_execute
      yield
    rescue => e
      raise e if e.class == ::CryptoEarn::InterestNotExistsError # expected error
      Bugsnag.notify(SilentExecuteError.new(e))
    end

    def run_handles(command)
      ActiveRecord::Base.transaction do
        command_handlers.select do |h|
          h.class.handles_message?(command)
        end.each { |h| h.handle(command) }
      end
    end

    def command_handlers
      @configuration.command_handlers
    end
  end
end
