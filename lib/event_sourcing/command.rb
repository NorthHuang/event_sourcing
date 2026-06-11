# frozen_string_literal: true

module EventSourcing
  class Command
    include Helpers::AttributeSupport
    include ActiveModel::Validations

    def initialize(args)
      update_all_attributes args
    end

    def slice(*methods)
      Hash[methods.map! { |method| [method, public_send(method)] }]
    end
  end
end
