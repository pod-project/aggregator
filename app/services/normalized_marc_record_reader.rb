# frozen_string_literal: true

# Utility class for reading marc records out of a set of uploads
# and filtering any obsolete records so we only get the latest
# version of each record.
class NormalizedMarcRecordReader
  include Enumerable

  attr_reader :uploads, :thread_pool_size

  # @param [Array<Upload>] uploads
  def initialize(uploads, thread_pool_size: 10)
    @uploads = uploads
    @thread_pool_size = thread_pool_size
  end

  # @yield [MarcRecord]
  def each(...)
    # pool = Concurrent::FixedThreadPool.new(thread_pool_size)

    current_marc_record_ids.each_slice(200) do |slice|
      records = MarcRecord.find(slice)

      # do a little pre-processing to pre-generated the augmented MARC.
      # this is done in a thread pool for a marginal performance boost
      # (10-15%).
      # records.each do |record|
      #   # pool.post { record.augmented_marc }
      #   record.augmented_marc
      # rescue StandardError
      #   nil
      # end

      records.each(...)
    end

    pool.shutdown
  end

  # Return the full list of MarcRecord id values to include in the dump.
  # Note: ideally we'd be able to iterate through that list, but e.g. #find_each
  #   does not support custom ordering (which we need in order to ensure we identify
  #   the most recent record for each 001)
  # @return [Array<Integer>] the list of MarcRecord id values
  def current_marc_record_ids
    return __pgsql_current_marc_record_ids if using_postgres?

    hash = {}

    # But for other databases, we'll have to do it ourselves.
    MarcRecord.select(:marc001, :id).where(upload: uploads).order(file_id: :asc, id: :asc).each do |record|
      hash[record.marc001] = record.id
    end

    hash.values
  end

  private

  def using_postgres?
    defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) &&
      ActiveRecord::Base.connection == ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  end

  def __pgsql_current_marc_record_ids
    # Postgres has 'SELECT DISTINCT ON', so we can have the database de-dupe marc records with the same 001
    # and return the most recent
    inner_query = MarcRecord.select('DISTINCT ON (marc001) *').where(upload: uploads).order('marc001, file_id DESC, id ASC')

    MarcRecord.from(inner_query, :marc_records).order(file_id: :asc, id: :asc).pluck(:id)
  end
end
