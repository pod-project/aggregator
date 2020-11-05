# frozen_string_literal: true

# :nodoc:
class Upload < ApplicationRecord
  has_paper_trail
  belongs_to :stream, touch: true
  has_one :organization, through: :stream
  has_many :marc_records, dependent: :delete_all

  has_many_attached :files

  after_commit do
    ExtractMarcRecordMetadataJob.perform_later(self)
  end

  def name
    super.presence || created_at&.iso8601
  end

  def analyzed?
    files.all?(&:analyzed?)
  end
end
