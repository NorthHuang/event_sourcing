# frozen_string_literal: true

module EventSourcing
  module MemoizationStore
    class Base
      class << self
        def write(key, value); end
        def read(key); end
      end
    end
  end
end
