# frozen_string_literal: true

##
# Background job to create full stream files for an organization
class GenerateFullDumpJob < GenerateDumpJob
  after_perform do |job|
    GenerateDeltaDumpJob.perform_later(*job.arguments)
  end

  # Only process organizations with changes since last full dump
  def self.enqueue_all
    organizations = Organization.select do |org|
      full_dump = org.default_stream.normalized_dumps.last
      next if full_dump && org.default_stream.uploads.where(updated_at: full_dump.last_full_dump_at...Time.zone.now).none?
    end

    organizations.each { |org| perform_later(org) }
  end

  private

  # Skip deletes when writing a full dump
  def write_record(record)
    return if record.status == 'delete'

    writers.each { |writer| writer.write_marc_record(record) }
  end

  def full_dump
    dump
  end

  def dump
    @dump ||= @organization.default_stream.normalized_dumps
                           .create(last_full_dump_at: Time.zone.now,
                                   last_delta_dump_at: Time.zone.now)
  end

  def uploads
    @organization.default_stream.uploads.active
  end

  def base_name
    "#{@organization.slug}-#{Time.zone.today}-full"
  end
end
