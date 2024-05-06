# frozen_string_literal: true

##
# https://edgeapi.rubyonrails.org/classes/ActiveStorage/Analyzer/ImageAnalyzer.html#method-i-metadata
class MarcAnalyzer < ActiveStorage::Analyzer
  def self.accept?(blob)
    MarcRecordService.new(blob).identify != :unknown
  end

  def metadata
    metadata = { analyzer: self.class.to_s, count:, type: }
    return metadata.merge(valid: false, error: 'No MARC records found') if count.zero?

    MarcProfilingJob.perform_later(blob, count:)

    metadata
  rescue MARC::XMLParseError, MARC::Exception => e
    Rails.logger.info(e)
    Honeybadger.notify(e)

    { analyzer: self.class.to_s, valid: false, error: e.message }
  end

  def type
    @type ||= reader.identify
  end

  def reader
    @reader ||= MarcRecordService.new(blob)
  end

  def count
    @count ||= reader.count
  end
end
