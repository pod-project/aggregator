# frozen_string_literal: true

##
# Background job to generate interstream delta between a stream and its predecessor
class GenerateInterstreamDeltaJob < ApplicationJob
  with_job_tracking

  def self.generate_interstream_delta_for_stream(stream)
    stream = Stream.find(stream) if stream.is_a? Integer
    return if stream.nil?

    GenerateInterstreamDeltaJob.perform_later(stream)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def perform(stream)
    # TODO: Cory: Test this.
    return if stream.previous_default.blank?

    previous_stream = stream.previous_default

    current_stream_dump = stream.current_full_dump
    previous_stream_dump = previous_stream.current_full_dump

    return unless current_stream_dump && previous_stream_dump

    # compare full dump of full stream vs previous stream's full dump + its deltas
    # Get full dump and its records
    comparison_hash = {}
    updates_and_additions = []
    previous_stream_reader = MarcRecordService.new(previous_stream_dump.marcxml.blob)
    previous_stream_reader.each_slice(100) do |batch|
      batch.each do |record|
        comparison_hash[record['001'].value] = record
      end
    end

    # Then one-by-one adjust according to each delta from oldest to newest
    previous_stream_deltas = previous_stream_dump.deltas.order(created_at: :asc)
    previous_stream_deltas.each do |delta|
      # rubocop:disable Style/Next, Style/SafeNavigation
      if delta.marcxml.blob
        delta_reader = MarcRecordService.new(delta.marcxml.blob)
        delta_reader.each_slice(100) do |batch|
          batch.each do |record|
            comparison_hash[record['001'].value] = record
          end
        end
      end
      if delta.deletes.blob
        delta.deletes.blob.open do |tempfile|
          delete_ids = tempfile.read.split
          delete_ids.each do |delete_id|
            comparison_hash.delete(delete_id) if comparison_hash.key?(delete_id)
          end
        end
      end
      # rubocop:enable Style/Next, Style/SafeNavigation
    end

    current_stream_reader = MarcRecordService.new(current_stream_dump.marcxml.blob)
    current_stream_reader.each_slice(100) do |batch|
      batch.each do |record|
        if comparison_hash.key?(record['001'].value) && comparison_hash[record['001'].value] == record
          # Matching record that has not been updated
          # per the code in the marc record class: https://github.com/ruby-marc/ruby-marc/blob/master/lib/marc/record.rb
          # == appears to be a safe way to compare MARC::Record objects
          comparison_hash.delete(record['001'].value)
        elsif comparison_hash.key?(record['001'].value)
          # Matching records that have been updated, are added to updates_and_additions and removed from comparison
          updates_and_additions << record
          comparison_hash.delete(record['001'].value)
        else
          # New records are added to updates_and_additions
          updates_and_additions << record
        end
      end
    end

    deletions = comparison_hash.keys

    # Create Files
    base_name = "#{stream.organization.slug}_interstreamdelta_#{previous_stream.id}_#{stream.id}".strip

    mrc_tempfile = Tempfile.new("#{base_name}.mrc")
    writer = MARC::Writer.new(mrc_tempfile)
    updates_and_additions.each do |record|
      writer.write(record)
    end
    writer.close

    xml_tempfile = Tempfile.new("#{base_name}.xml")
    xml_writer = MARC::XMLWriter.new(xml_tempfile)
    updates_and_additions.each do |record|
      xml_writer.write(record)
    end
    xml_writer.close

    delete_tempfile = Tempfile.new("#{base_name}.del.txt")
    File.write(delete_tempfile, deletions.join("\n"))

    # Attach Files
    unless current_stream_dump.interstream_delta
      current_stream_dump.interstream_delta = InterstreamDelta.create(normalized_dump: current_stream_dump, stream: stream)
    end

    current_stream_dump.interstream_delta.public_send(:marc21).attach(io: File.open(mrc_tempfile), filename: "#{base_name}.mrc")
    current_stream_dump.interstream_delta.public_send(:marcxml).attach(io: File.open(xml_tempfile), filename: "#{base_name}.xml")
    # rubocop:disable Layout/LineLength
    current_stream_dump.interstream_delta.public_send(:deletes).attach(io: File.open(delete_tempfile), filename: "#{base_name}.del.txt")
    # rubocop:enable Layout/LineLength
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
