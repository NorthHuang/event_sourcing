# frozen_string_literal: true

require 'request_store'

# this store requires the request_store gem
module EventSourcing
  module MemoizationStore
    class RequestStore < Base
      class << self
        def write(key, value)
          ::RequestStore[key] = value
        end

        def read(key)
          ::RequestStore[key]
        end
      end
    end
  end
end
