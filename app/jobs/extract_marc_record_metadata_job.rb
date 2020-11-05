# frozen_string_literal: true

require 'nokogiri'

# Extract MarcRecord instances from an upload
class ExtractMarcRecordMetadataJob < ApplicationJob
  queue_as :default
  retry_on Exceptions::UploadNotAnalzyed, attempts: 10, wait: :exponentially_longer

  def perform(upload)
    raise Exceptions::UploadNotAnalzyed unless upload.analyzed?

    upload.with_lock do
      upload.marc_records.delete_all

      upload.files.each do |file|
        extract_marc_record_metadata(upload, file)
      end
    end
  end

  def extract_marc_record_metadata(upload, file, batch_size: 100)
    enumerable = if file.blob.content_type.ends_with?('xml') || file.blob.filename.to_s.ends_with?('xml')
                   extract_marc_record_metadata_from_marc_xml(upload, file)
                 else
                   extract_marc_record_metadata_from_marc_binary(upload, file)
                 end

    enumerable.each_slice(batch_size) do |batch|
      # rubocop:disable Rails/SkipsModelValidations
      MarcRecord.insert_all(batch, returning: false)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def extract_marc_record_metadata_from_marc_xml(upload, file)
    return to_enum(:extract_marc_record_metadata_from_marc_xml, upload, file) unless block_given?

    file.blob.open do |tmpfile|
      marc_reader = MARC::XMLReader.new(tmpfile, parser: 'nokogiri')

      marc_reader.each.with_index do |record, index|
        yield({
          marc001: record['001']&.value,
          file_id: file.id,
          upload_id: upload.id,
          index: index,
          checksum: Digest::MD5.hexdigest(record.to_xml.to_s)
        })
      end
    end
  end

  def extract_marc_record_metadata_from_marc_binary(upload, file)
    return to_enum(:extract_marc_record_metadata_from_marc_binary, upload, file) unless block_given?

    file.blob.open do |tmpfile|
      args = { invalid: :replace }
      marc_reader = MARC::Reader.new(tmpfile, args)

      each_with_bytecount(marc_reader).with_index do |(bytes, bytecount, length), index|
        record = MARC::Reader.decode(bytes)

        yield({
          marc001: record['001']&.value,
          file_id: file.id,
          upload_id: upload.id,
          bytecount: bytecount,
          length: length,
          index: index,
          checksum: Digest::MD5.hexdigest(bytes)
        })
      end
    end
  end

  def each_with_bytecount(reader)
    return to_enum(:each_with_bytecount, reader) unless block_given?

    bytecount = 0

    reader.each_raw do |bytes|
      length = bytes[0...5].to_i
      yield bytes, bytecount, length
      bytecount += length
    end
  end
end
