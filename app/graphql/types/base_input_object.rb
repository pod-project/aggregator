# frozen_string_literal: true

module Types
  # :nodoc:
  class BaseInputObject < GraphQL::Schema::InputObject
    argument_class Types::BaseArgument
  end
end
