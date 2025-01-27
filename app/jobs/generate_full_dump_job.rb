# frozen_string_literal: true

##
# Background job to create a full dump download for a resource (organization)
class GenerateFullDumpJob < ApplicationJob
  with_job_tracking

  def self.enqueue_all
    Organization.find_each do |org|
      full_dump = org.default_stream.normalized_dumps.published.last
      next if full_dump && org.default_stream.uploads.where(updated_at: full_dump.last_full_dump_at...Time.zone.now).none?

      GenerateFullDumpJob.perform_later(org)
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
  def perform(organization)
    now = Time.zone.now
    uploads = Upload.active.where(stream: organization.default_stream)

    uploads.where.not(status: 'processed').find_each do |upload|
      ExtractMarcRecordMetadataJob.perform_now(upload)
    end

    progress.total = uploads.sum(&:marc_records_count)

    full_dump = organization.default_stream.normalized_dumps.build(last_full_dump_at: now, last_delta_dump_at: now)

    base_name = "#{organization.slug}-#{Time.zone.today}-full"
    writer = MarcRecordWriterService.new(base_name)
    oai_file_counter = 0

    begin
      NormalizedMarcRecordReader.new(uploads).each_slice(Settings.oai_max_page_size) do |records|
        # See note here on CPU saturation:
        # https://github.com/mperham/sidekiq/discussions/5039
        Thread.pass

        oai_writer = OaiMarcRecordWriterService.new(base_name)
        records.each do |record|
          # In a full dump, we can omit the deletes
          next if record.status == 'delete'

          # Rails.logger.error("Processed record #{record.id} # #{record.marc001}")
          puts "Processed record #{record.id} # #{record.marc001}"
          writer.write_marc_record(record)
          oai_writer.write_marc_record(record, now)
        end

        if oai_writer.bytes_written?
          oai_writer.finalize
          full_dump.oai_xml.attach(io: File.open(oai_writer.oai_file),
                                   filename: human_readable_filename(
                                     base_name, :oai_xml, oai_file_counter
                                   ))
        end

        oai_file_counter += 1
        # Save the dump once for every 100 oai files to free up file handles
        full_dump.save! if (oai_file_counter % 100).zero?
        progress.increment(records.length)
      ensure
        oai_writer.finalize
        oai_writer.close
        oai_writer.unlink
      end

      writer.finalize

      writer.files.each do |as, file|
        full_dump.public_send(as).attach(io: File.open(file), filename: human_readable_filename(base_name, as))
      end

      # Add a timestamp when the dump is saved at the end of the job to indicate
      # it is complete, should supercede the previous full dump, and is ready for harvesting.
      full_dump.published_at = Time.zone.now
      full_dump.save!

      GenerateDeltaDumpJob.perform_later(organization)
    ensure
      writer.close
      writer.unlink
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity

  def human_readable_filename(base_name, file_type, counter = nil)
    as = case file_type
         when :deletes
           'deletes.del.txt'
         when :marc21
           'marc21.mrc.gz'
         when :marcxml
           'marcxml.xml.gz'
         when :oai_xml
           "oai-#{format('%010d', counter)}.xml.gz"
         else
           "#{file_type}.gz"
         end

    "#{base_name}-#{as}"
  end
end
