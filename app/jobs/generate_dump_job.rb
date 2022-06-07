# frozen_string_literal: true

##
# Background job to create downloadable files representing an organization's stream
class GenerateDumpJob < ApplicationJob
  with_job_tracking

  def perform(organization)
    @organization = organization
    return unless full_dump && uploads.any?

    # ensure all uploads have been processed before starting
    uploads.where.not(status: 'processed').each do |upload|
      ExtractMarcRecordMetadataJob.perform_now(upload)
    end

    write_files

    dump.save!
    full_dump.update(last_delta_dump_at: Time.zone.now)
  end

  private

  # Write all MARC records to tempfiles using the configured writers
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  def write_files
    progress.total = uploads.sum(&:marc_records_count)

    NormalizedMarcRecordReader.new(uploads).each_slice(100) do |records|
      records.each { |record| write_record(record) }
      progress.increment(records.length)
    end

    writers.each(&:finalize)
    writers.each { |writer| writer.attach_files_to_dump(dump, base_name) }
  ensure
    writers.each(&:close)
    writers.each(&:unlink)
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity

  # Write a single MARC record/delete using each writer
  def write_record(record)
    if record.status == 'delete'
      writers.each { |writer| writer.write_delete(record) }
    else
      writers.each { |writer| writer.write_marc_record(record) }
    end
  end

  # Services that support #write_marc_record and #write_delete
  def writers
    @writers ||= [
      MarcRecordWriterService.new(base_name),
      OaiMarcRecordWriterService.new(base_name)
    ]
  end
end
