unless defined?(Boolean)
  module Boolean; end
  class TrueClass; include Boolean; end
  class FalseClass; include Boolean; end
end
