# frozen_string_literal: true

module EventSourcing
  module Helpers
    module AttributeSupport
      def self.included(base)
        base.extend ClassMethods
      end

      def all_attributes
        Hash[
          self.class.attr_types.map do |attr_name, _|
            [attr_name, public_send(attr_name)]
          end
        ]
      end

      def update_attributes_with_type(attrs)
        self.class.attr_types.each do |attr_name, attr_type|
          next unless attrs[attr_name.to_sym]
          instance_variable_set(
            "@#{attr_name}",
            cast_type(attr_name, attrs[attr_name.to_sym], attr_type)
          )
        end
        self
      end

      def update_attribute_with_type(attr_name, value)
        attr_type = self.class.attr_types[attr_name]
        instance_variable_set(
          "@#{attr_name}",
          cast_type(attr_name, value, attr_type)
        )
        self
      end

      private

      def cast_type(attr_name, value, type)
        return nil if value.nil?
        case
        when type.is_a?(Array)
          value.map { |v| cast_type(attr_name, v, type.first) }
        when type < EventSourcing::BaseType
          Hash[
            value.map do |key, v|
              new_value =
                if type.fields[key.to_sym]
                  cast_type(attr_name, v, type.fields[key.to_sym][0])
                else
                  v
                end
              [key.to_sym, new_value]
            end
          ]
        when type == Object
          value
        when type == Boolean
          value
        when type == Symbol
          value.to_sym
        when type == Integer
          value.to_i
        when type == Float
          value.to_f
        when type == BigDecimal
          value.to_d
        when type == String
          value.to_s
        when type == Time
          Time.find_zone('UTC').parse(value)
        when type == DateTime
          DateTime.parse(value)
        else
          raise EventSourcing::BaseType::UnsupportedType.new(
            self,
            attr_name,
            value,
            type
          )
        end
      end

      module ClassMethods
        attr_reader :attr_types
        attr_reader :attr_options

        def attrs(attribute, type, options = {})
          @attr_types ||= {}
          @attr_types.merge!(Hash[attribute, type])

          @attr_options ||= {}
          options =
            {
              # optional field - can be nil
              optional: false
            }.merge(options)
          @attr_options.merge!(Hash[attribute, options])

          attr_accessor attribute # end #   Sequent::Helpers::DefaultValidators.for(type).add_validations_for(self, attribute) # if included_modules.include?(Sequent::Helpers::TypeConversionSupport)

          # if type.class == Sequent::Helpers::ArrayWithType
          #   associations << attribute
          # elsif included_modules.include?(ActiveModel::Validations) &&
          #   type.included_modules.include?(Sequent::Helpers::AttributeSupport)
          #   associations << attribute
          # end

          class_eval <<EOS
            def update_all_attributes(attrs)
              super if defined?(super)
              #{
            @attr_types.map { |attr, _| "@#{attr} = attrs[:#{attr}]" }.join(
              "\n            "
            )
          }
              self
            end

            def validate_types!
              super if defined?(super)
              #{
            @attr_types.map { |attr, _| "validate_type!(:#{attr})" }.join(
              "\n            "
            )
          }
            end

            def validate_type!(attr_name)
              value = instance_variable_get("@\#{attr_name}")
              attr_type = self.class.attr_types[attr_name]
              options = self.class.attr_options[attr_name]
              return if value.nil? && options[:optional]
              unless value.is_a?(attr_type)
                raise EventSourcing::BaseType::ValidationError.new(self, attr_name, attr_type, value.class)
              end
            end
EOS
        end
      end
    end
  end
end
