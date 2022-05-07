# frozen_string_literal: true

# :nodoc:
class Stream < ApplicationRecord
  has_paper_trail
  extend FriendlyId
  friendly_id :name, use: %i[finders slugged scoped], scope: :organization
  belongs_to :organization
  has_many :uploads, dependent: :destroy
  has_many :marc_records, through: :uploads, inverse_of: :stream
  has_many :files, source: :files_blobs, through: :uploads
  has_one :statistic, dependent: :delete, as: :resource
  has_many :normalized_dumps, dependent: :destroy
  has_many :job_trackers, dependent: :delete_all, as: :reports_on

  scope :default, -> { where(default: true) }
  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }

  has_many_attached :snapshots

  before_destroy :preserve_default_streams
  after_create :check_for_a_default_stream

  # :nodoc:
  class CannotMakeStreamDefault < StandardError
    def message
      'Current and former default streams cannot be made the default.'
    end
  end

  # :nodoc:
  class CannotDestroyStream < StandardError
    def message
      'Current and former default streams cannot be deleted.'
    end
  end

  def display_name
    name.presence || default_name
  end

  def archive
    update(status: 'archived', default: false)
    uploads.find_each(&:archive)
  end

  def make_default
    raise(DefaultStreamIntegrityViolation) unless can_make_default?

    Stream.transaction do
      organization.streams.default.each do |stream|
        stream.update(default: false, default_end_time: DateTime.now)
      end
      update(default: true)
      update(default_start_time: DateTime.now)
    end
  end

  def can_make_default?
    default.blank? && default_start_time.blank? && default_end_time.blank?
  end

  def can_destroy?
    default.blank? && default_start_time.blank? && default_end_time.blank?
  end

  def previous_default
    organization.streams.order(default_end_time: :desc).where('default_end_time < ?', default_start_time).first
  end

  def job_tracker_status_groups
    {
      needs_attention: job_trackers.select { |jt| jt.in_retry_set? || jt.in_dead_set? },
      active: job_trackers.select { |jt| !jt.in_retry_set? && !jt.in_dead_set? }
    }
  end

  def active_jobs?
    job_tracker_status_groups.values.flatten.any?
  end

  def marc_profile
    any = false
    profile = MarcProfile.new(count: 0, histogram_frequency: {}, record_frequency: {}, sampled_values: {})

    files.find_each do |blob|
      blob_profile = MarcProfile.find_by(blob_id: blob.id)
      next unless blob_profile

      any = true
      profile.deep_merge!(blob_profile)
    end

    return unless any

    profile
  end

  def current_full_dump
    @current_full_dump ||= normalized_dumps.full_dumps.last ||
                           normalized_dumps.full_dumps.create(last_delta_dump_at: Time.zone.at(0))
  end

  private

  def preserve_default_streams
    raise(CannotDestroyStream) unless can_destroy? || destroyed_by_association
  end

  def default_name
    "#{I18n.l(created_at.to_date)} - #{default? ? '' : I18n.l(updated_at.to_date)}"
  end

  def check_for_a_default_stream
    return unless organization.streams.count == 1

    update(default_start_time: DateTime.now)
  end
end
