# frozen_string_literal: true

module Types
  # :nodoc:
  class OrganizationType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :slug, String, null: true
    field :last_delta_dump_at, GraphQL::Types::ISO8601DateTime, null: true
    field :code, String, null: true
    # field :normalization_steps, Types::JsonType, null: true
    field :public, Boolean, null: true
    field :name, String, null: true
    field :slug, String, null: true
    field :records, [MarcRecordType], null: true do
      description 'Return all MARC records'
      argument :filter, [String], required: false
      argument :limit, Integer, required: false
    end

    def records(limit: 25, **args, &block)
      return to_enum(:records, **args, limit: limit) unless block

      with_limit(limit, **args, &block)
    end

    def with_limit(limit, **args, &block)
      return filter_records(**args, &block) unless limit

      i = 0

      filter_records(**args).each do |record|
        yield record
        i += 1
        break if i >= limit
      end
    end

    def each_record(&block)
      return to_enum(:each_record) unless block

      object.default_stream.uploads.find_each do |upload|
        upload.each_marc_record_metadata(&block)
      end
    end

    def filter_records(filter: nil, &block)
      return to_enum(:filter_records, filter: filter) unless block

      return each_record(&block) unless filter

      each_record do |record|
        yield record if filter.all? { |f| evaluate_marcspec_filter(record.marc, f) }
      end
    end

    def evaluate_marcspec_filter(record, filter)
      if filter.include?('$')
        field, subfield = filter.split('$', 2)

        record.fields(field).any? do |f|
          f[subfield]
        end
      elsif filter.match?(/^\d{3}[a-z]$/)
        field = filter[0..2]
        subfield = filter[3]
        evaluate_marcspec_filter(record, "#{field}$#{subfield}")
      else
        record.marc[filter]
      end
    end
  end
end
