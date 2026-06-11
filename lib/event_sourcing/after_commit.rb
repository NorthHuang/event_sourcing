# frozen_string_literal: true

module EventSourcing
  class AfterCommit
    def initialize(callback)
      @callback = callback
    end

    def committed!(*)
      @callback.call
    end

    def before_committed!(*); end

    def add_to_transaction(*); end

    def rolledback!(*); end

    module Helper
      def after_commit(connection: ActiveRecord::Base.connection, &block)
        connection.add_transaction_record(AfterCommit.new(block))
      end
    end
  end
end
