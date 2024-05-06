# frozen_string_literal: true

require 'rubygems/package'

##
# Job to extract tar.gz files in the background
class ExtractFilesJob < ApplicationJob
  queue_as :default

  def perform(upload)
    return unless any_multifile?(upload)

    upload.update(status: 'processing')

    non_multifile_upload = nil

    upload.files.each do |attachment|
      if multifile?(attachment)
        extract_multifile_attachment(attachment, upload)
      else
        non_multifile_upload ||= upload.stream.uploads.build.tap { |x| x.save(validate: false) }
        attachment.update(record: non_multifile_upload)
      end
    end

    upload.update(status: 'archived')
  end

  def extract_multifile_attachment(src, upload)
    each_file(src).map do |entry|
      Tempfile.create(binmode: true) do |file|
        writer = Zlib::GzipWriter.new(file)
        IO.copy_stream(entry, writer)
        writer.close
        file.close

        dest = upload.stream.uploads.build
        dest.files.attach({ io: File.open(file), filename: entry.full_name })
        dest.save!
      end
    end
  end

  def each_file(attachment, limit: 1000)
    return to_enum(:each_file, attachment, limit:) unless block_given?

    counter = 0

    attachment.blob.open do |tmpfile|
      io = Gem::Package::TarReader.new(Zlib::GzipReader.new(tmpfile))

      io.each.with_index do |entry, index|
        break if index > counter

        next unless entry.file?

        yield entry
        counter += 1
      end
    end
  end

  def any_multifile?(upload)
    upload.files.any? do |attachment|
      multifile?(attachment)
    end
  end

  def multifile?(attachment)
    blob = attachment.blob
    chunk = blob.service.download_chunk(blob.key, 0..(2.kilobytes))

    return false unless chunk

    # tar.gz magic bytes
    if chunk.bytes[0] == 0x1F && chunk.bytes[1] == 0x8B
      reader = Zlib::GzipReader.new(StringIO.new(chunk))
      str = reader.read(0x106)

      return str[0x101...0x106] == 'ustar'
    end

    false
  end
end
