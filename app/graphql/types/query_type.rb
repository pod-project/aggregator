# frozen_string_literal: true

module Types
  # :nodoc:
  class QueryType < Types::BaseObject
    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :organization, OrganizationType, null: false do
      description 'Find an organization by ID'
      argument :id, ID, required: true
    end

    def organization(id:)
      Organization.friendly.find(id)
    end
  end
end
