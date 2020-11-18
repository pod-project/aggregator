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
  validates :url, presence: true, if: proc { |upload| upload.files.blank? }
  validates :files, presence: true, if: proc { |upload| upload.url.blank? }
  validate :valid_url, if: proc { |upload| upload.url.present? }

  after_create :attach_file_from_url

  has_many_attached :files

  after_commit do
    ExtractMarcRecordMetadataJob.perform_later(self)
  end

  def name
    super.presence || created_at&.iso8601
  end

  def each_marc_record_metadata(&block)
    return to_enum(:each_marc_record_metadata) unless block_given?

    files.each do |file|
      service = MarcRecordService.new(file.blob)

      format = service.identify

      next if format == :unknown

      extract_marc_record_metadata(file, service, &block)
    end
  end

  private

  def valid_url
    errors.add(:url, 'Unable to attach file from URL') unless URI.parse(url)&.host
  end

  def attach_file_from_url
    return if url.blank?

    AttachRemoteFileToUploadJob.perform_later(self)
  end

  def extract_marc_record_metadata(file, service)
    return to_enum(:extract_marc_record_metadata, file, service) unless block_given?

    service.each_with_metadata do |record, metadata|
      out = MarcRecord.new(
        **metadata,
        marc001: record['001']&.value,
        file_id: file.id,
        upload_id: id,
        marc: record
      )

      out.checksum ||= Digest::MD5.hexdigest(record.to_xml.to_s)

      yield out
    end
  end
end
