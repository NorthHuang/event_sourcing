# frozen_string_literal: true

module EventSourcing
  class SilentExecuteError < StandardError
    attr_reader :original_error

    def initialize(error)
      @original_error = error
    end

    def message
      original_error.message
    end

    def context
      return {} unless original_error.respond_to?(:metadata)

      { metadata: original_error.metadata }
    end

    def backtrace
      original_error.backtrace
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
      raise e if silent_exception_reraise?(e)

      wrapped_error = SilentExecuteError.new(e)
      @configuration.report_error(
        wrapped_error,
        context: {
          operation: "command_service.execute",
          original_error_class: e.class.name
        }.merge(wrapped_error.context)
      )
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

    def silent_exception_reraise?(error)
      Array(@configuration.silent_exception_reraise_errors)
        .any? { |error_class| error.is_a?(error_class) }
    end
  end
end
