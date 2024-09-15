# frozen_string_literal: true

module EventSourcing
  # AfterOutermostCommit is similar to AfterCommit but only be run after the
  # outermost transaction has been committed, while AfterCommit is attached
  # to current transaction which is a savepoint in rails's pg db
  # implementation. Useful for scheduling sidekiq jobs.
  # If not currently in a transaction, will execute immediately
  class AfterOutermostCommit
    def initialize
      @callback = Proc.new
    end

    # :nocov:
    def self.transaction_open?
      ActiveRecord::Base.connection.transaction_open?
    end

    # :nocov:

    if defined?(::Rails)
      if ::Rails.env.test?
        class << self
          attr_writer :test_transaction

          def transaction_open?
            ActiveRecord::Base.connection.current_transaction != @test_transaction
          end
        end
      end
    end

    def committed!(*)
      if self.class.transaction_open?
        # Nested transaction. Pass the callback to the parent
        ActiveRecord::Base.connection.add_transaction_record(self)
      else
        @callback.call
      end
    end

    def before_committed!(*); end

    def add_to_transaction(*); end

    def rolledback!(*); end

    module Helper
      def after_outermost_commit(connection: ActiveRecord::Base.connection)
        return yield unless AfterOutermostCommit.transaction_open?

        connection.add_transaction_record(AfterOutermostCommit.new(&Proc.new))
      end
    end
  end
end
