# frozen_string_literal: true

json.total @response&.values&.sum(&:count) || 0
json.isbn index_params[:isbn]
json.organizations @response do |organization, records|
  json.extract! organization, :id, :name, :slug
  json.records records do |record|
    json.extract! record, :id, :marc001, :bytecount, :length, :checksum
    json.url organization_marc_record_url(record.organization, record)
  end
end
