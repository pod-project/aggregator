# frozen_string_literal: true

# :nodoc:
class Upload < ApplicationRecord
  has_paper_trail
  belongs_to :stream, touch: true
  has_one :organization, through: :stream
  has_many :marc_records, dependent: :delete_all
  has_many :marc_profiles, dependent: :delete_all
  belongs_to :user, optional: true
  belongs_to :allowlisted_jwts, optional: true
  validate :url_presence_if_no_uploaded_files
  validates :files, presence: true, if: proc { |upload| upload.url.blank? }
  validate :valid_url, if: proc { |upload| upload.url.present? }
  scope :active, -> { where(status: %w[active processed]) }
  scope :archived, -> { where(status: 'archived') }
  scope :recent, -> { order(created_at: :desc) }

  after_create :attach_file_from_url

  after_save_commit :perform_extract_marc_record_metadata_job, if: :active?
  after_save_commit :perform_extract_files_job, if: :active?

  # This should be after any callbacks that interact with the attached upload
  # See https://github.com/rails/rails/issues/37304
  has_many_attached :files

  def active?
    status == 'active'
  end

  def processed?
    status == 'processed'
  end

  def name
    super.presence || created_at&.iso8601
  end

  def archive
    update(status: 'archived')
    files.find_each(&:purge_later)
  end

  # rubocop:disable Metrics/MethodLength, Style/ArgumentsForwarding
  def read_marc_record_metadata(**options, &block)
    return to_enum(:read_marc_record_metadata, **options) unless block

    files.each do |file|
      service = MarcRecordService.new(file.blob)

      format = service.identify

      case format
      when :delete
        extract_marc_record_delete_metadata(file, &block)
      when :unknown
        next
      else
        extract_marc_record_metadata(file, service, **options, &block)
      end
    rescue StandardError => e
      Honeybadger.notify(e)
      raise if e.instance_of?(ActiveStorage::FileNotFoundError)
    end
  end
  # rubocop:enable Metrics/MethodLength, Style/ArgumentsForwarding

  private

  def url_presence_if_no_uploaded_files
    errors.add(:url, 'A URL must be provided if a file has not been uploaded') if !files.attached? && url.blank?
  end

  def perform_extract_marc_record_metadata_job
    ExtractMarcRecordMetadataJob.perform_later(self)
  end

  def perform_extract_files_job
    ExtractFilesJob.perform_later(self)
  end

  def valid_url
    errors.add(:url, 'Unable to attach file from URL') unless URI.parse(url)&.host
  end

  def attach_file_from_url
    return if url.blank?

    AttachRemoteFileToUploadJob.perform_later(self)
  end

  def extract_marc_record_delete_metadata(file)
    return to_enum(:extract_marc_record_delete_metadata, file) unless block_given?

    file.blob.open do |tmpfile|
      tmpfile.each_line do |line|
        yield MarcRecord.new(
          marc001: line.strip,
          file:,
          upload: self,
          status: 'delete'
        )
      end
    end
  end

  def extract_marc_record_metadata(file, service, checksum: true)
    return to_enum(:extract_marc_record_metadata, file, service, checksum:) unless block_given?

    service.each_with_metadata do |record, metadata|
      out = MarcRecord.new(
        **metadata,
        file:,
        marc: record,
        upload: self
      )

      out.checksum ||= Digest::MD5.hexdigest(record.to_xml.to_s) if checksum

      yield out
    end
  end
end
