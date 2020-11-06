# frozen_string_literal: true

##
# https://edgeapi.rubyonrails.org/classes/ActiveStorage/Analyzer/ImageAnalyzer.html#method-i-metadata
class XmlMarcAnalyzer < ActiveStorage::Analyzer
  def self.accept?(blob)
    blob.content_type.ends_with?('xml') || blob.filename.to_s.include?('xml')
  end

  def metadata
    read_file do |file|
      { analyzer: self.class.to_s, count: file.count }
    end
  rescue MARC::XMLParseError, MARC::Exception => e
    Rails.logger.info(e)
    Honeybadger.notify(e)

    { analyzer: self.class.to_s, valid: false, error: e.message }
  end

  private

  def read_file
    download_blob_to_tempfile do |file|
      marc_reader = MARC::XMLReader.new(file)
      yield marc_reader
    end
  end
end
