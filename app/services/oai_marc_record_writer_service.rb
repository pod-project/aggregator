# frozen_string_literal: true

# Utility class for serializing MARC records to OAI-XML files
class OaiMarcRecordWriterService
  attr_reader :base_name, :files

  def initialize(base_name = nil)
    @base_name = base_name
    @files = []
    @records_written = 0
    @oai_writer = OAIPMHWriter.new(Zlib::GzipWriter.new(temp_file))
  end

  def write_marc_record(record)
    next_file if @records_written == Settings.oai_max_page_size

    oai_writer.write(record.augmented_marc, record.oai_id, record.stream.id, record.upload.created_at)
    @records_written += 1
  rescue StandardError => e
    error = "Error writing MARC OAI file #{record.oai_id}: #{e}"
    Rails.logger.info(error)
    Honeybadger.notify(error)
  end

  def write_delete(record)
    next_file if @records_written == Settings.oai_max_page_size

    oai_writer.write_delete(record.oai_id, record.stream.id, record.upload.created_at)
    @records_written += 1
  end

  def finalize
    @oai_writer&.close
  end

  def close
    @files.each(&:close)
  end

  def unlink
    @files.each(&:unlink)
  end

  def attach_files_to_dump(dump, base_name)
    files.each_with_index do |file, counter|
      dump.public_send(:oai_xml).attach(io: File.open(file), filename: human_readable_filename(base_name, counter))
    end
  end

  private

  def next_file
    @oai_writer&.close
    @oai_writer = OAIPMHWriter.new(Zlib::GzipWriter.new(temp_file))
    @records_written = 0
  end

  def temp_file
    Tempfile.new("#{base_name}-oai_xml", binmode: true).tap do |file|
      @files << file
    end
  end

  def human_readable_filename(base_name, counter = nil)
    "#{base_name}-oai-#{format('%010d', counter)}.xml.gz"
  end

  # Special logic for writing OAI-PMH-style record responses
  class OAIPMHWriter
    attr_reader :bytes_written

    def initialize(io)
      @io = io
      @bytes_written = 0
    end

    def write(record, identifier, set, datestamp = Time.zone.now)
      @bytes_written += @io.write <<-EOXML
        <record>
          <header>
            <identifier>#{identifier}</identifier>
            <datestamp>#{datestamp.strftime('%F')}</datestamp>
            <setSpec>#{set}</setSpec>
          </header>
          <metadata>
            #{MARC::XMLWriter.encode(record, include_namespace: true)}
          </metadata>
        </record>
      EOXML
    end

    def write_delete(identifier, set, datestamp = Time.zone.now)
      @bytes_written += @io.write <<-EOXML
        <record>
          <header status="deleted">
            <identifier>#{identifier}</identifier>
            <datestamp>#{datestamp.strftime('%F')}</datestamp>
            <setSpec>#{set}</setSpec>
          </header>
        </record>
      EOXML
    end

    def bytes_written?
      @bytes_written.positive?
    end

    def close
      @io.close
    end
  end
end
