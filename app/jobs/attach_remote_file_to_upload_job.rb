# frozen_string_literal: true

##
# Job to upload files from a URL in the background
class AttachRemoteFileToUploadJob < ApplicationJob
  queue_as :default
  with_job_tracking

  def perform(upload)
    io = URI.parse(upload.url).open
    upload.files.attach(io:, filename: filename_from_io(io) || filename_from_url(upload.url) || upload.name)
    upload.update(status: 'active')
  rescue SocketError, OpenURI::HTTPError => e
    error = "Error opening #{upload.url}: #{e}"
    Rails.logger.info(error)
    Honeybadger.notify(error)
    raise e
  end

  private

  def filename_from_io(io)
    content_disposition = io.meta['content-disposition']&.split(';') || []
    filenames = content_disposition.filter_map do |disp|
      key, value = disp.split('=')
      next unless key == 'filename'

      value
    end

    filenames&.first&.gsub(/^["']|["']$/, '')
  end

  def filename_from_url(url)
    potential_file_name = File.basename(url)

    return unless potential_file_name.include?('.')

    potential_file_name
  end

  def update_job_tracker_properties(tracker)
    super

    upload = arguments.first
    tracker.reports_on = upload&.stream
    tracker.resource = upload
  end
end
