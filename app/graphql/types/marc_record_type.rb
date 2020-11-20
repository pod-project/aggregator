# frozen_string_literal: true

module Types
  # :nodoc:
  class MarcRecordType < Types::BaseObject
    field :id, ID, null: false
    field :file_id, Integer, null: false
    field :upload_id, Integer, null: false
    field :marc001, String, null: true
    field :bytecount, Integer, null: true
    field :length, Integer, null: true
    field :index, Integer, null: true
    field :checksum, String, null: true
    field :leader, String, null: false
    field :fields, GraphQL::Types::JSON, null: false do
      argument :filter, [String], required: false
    end
    field :marchash, GraphQL::Types::JSON, null: false

    def leader
      object.marc.leader
    end

    def fields(filter: nil)
      object.marc.fields.select do |field|
        filter.nil? || filter.include?(field.tag)
      end.map(&:to_hash)
    end

    def marchash
      object.marc.to_marchash
    end
  end
end
