# frozen_string_literal: true

##
# Background job to create delta (changes/deletes) files for an organization
class GenerateDeltaDumpJob < GenerateDumpJob
  def self.enqueue_all
    Organization.each { |org| perform_later(org) }
  end

  private

  def full_dump
    @organization.default_stream.current_full_dump
  end

  def dump
    @dump ||= full_dump.deltas.create(stream_id: full_dump.stream_id)
  end

  # Only process uploads added to the stream since the last delta dump
  def uploads
    @organization.default_stream.uploads
                 .active
                 .where(created_at: full_dump.last_delta_dump_at...Time.zone.now)
  end

  def base_name
    "#{@organization.slug}-#{Time.zone.today}-delta"
  end
end
