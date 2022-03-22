# frozen_string_literal: true

json.name @stream.name
json.slug @stream.slug
json.url organization_stream_url(@stream.organization, @stream, format: :json)
json.uploads @stream.uploads do |upload|
  json.id upload.id
  json.name upload.name
  json.files upload.files do |file|
    json.id file.id
    json.filename file.filename
    json.hash "md5:#{Base64.decode64(file.checksum).unpack1('H*')}"
    json.type file.content_type
    json.length file.byte_size
    json.download_url download_url(file)
  end
end
