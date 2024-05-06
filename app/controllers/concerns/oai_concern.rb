# frozen_string_literal: true

##
# Misc. OAI-PMH functionality
module OaiConcern
  extend ActiveSupport::Concern

  # Base class for error conditions: see
  # http://www.openarchives.org/OAI/openarchivesprotocol.html#ErrorConditions
  class OaiError < StandardError; end

  # Raised by any request
  class BadArgument < OaiError
    def message
      'The request includes illegal or repeated arguments, or is missing required arguments'
    end
  end

  # Raised by any request
  class BadVerb < OaiError
    def message
      'The value of the verb argument is missing, repeated, or illegal'
    end
  end

  # Raised by ListIdentifiers, ListRecords, ListSets
  class BadResumptionToken < OaiError
    def message
      'The value of the resumptionToken argument is invalid or expired'
    end
  end

  # Raised by GetRecord, ListIdentifiers, ListRecords
  class CannotDisseminateFormat < OaiError
    def message
      'The metadata format specified by the metadataPrefix argument is not supported by the item or repository'
    end
  end

  # Raised by GetRecord, ListMetadataFormats
  class IdDoesNotExist < OaiError
    def message
      'The value of the identifier argument is unknown or illegal in this repository'
    end
  end

  # Raised by ListIdentifiers, ListRecords
  class NoRecordsMatch < OaiError
    def message
      'The combination of the values of the from, until, set and metadataPrefix arguments returns an empty list'
    end
  end

  # Token for requesting records: base64-encoded combo of filters & page cursor
  # A token lets you construct a list of records and point to somewhere in that
  # list.
  class ResumptionToken
    attr_reader :set, :page, :from_date, :until_date, :version

    def initialize(set: nil, page: nil, from_date: nil, until_date: nil)
      @set = set
      @page = page
      @from_date = from_date
      @until_date = until_date
      @version = ResumptionToken.version
      raise BadResumptionToken unless valid?
    end

    # Error if the token is invalid or if it is a version other than ours
    def self.decode(string)
      set, page, from_date, until_date, version = Base64.urlsafe_decode64(string).split(';')
      raise BadResumptionToken unless version == ResumptionToken.version

      token = ResumptionToken.new(set:, page:, from_date:, until_date:)
      raise BadResumptionToken unless token.valid?

      token
    end

    def self.version
      'v1.0'
    end

    def encode
      Base64.urlsafe_encode64([@set, @page, @from_date, @until_date, @version].join(';'))
    end

    # rubocop:disable Metrics/AbcSize
    # valid iff all values can be parsed and set/page are nonnegative integers
    def valid?
      Integer(set) if @set.present?
      Integer(page) if @page.present?
      Date.parse(from_date) if @from_date.present?
      Date.parse(until_date) if @until_date.present?
      !set.to_i.negative? && !page.to_i.negative?
    rescue ArgumentError
      false
    end
    # rubocop:enable Metrics/AbcSize
  end

  included do
    private

    # XML namespace values for OAI-PMH, see:
    # https://www.openarchives.org/OAI/openarchivesprotocol.html#XMLResponse
    def oai_xmlns
      {
        'xmlns' => 'http://www.openarchives.org/OAI/2.0/',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd'
      }
    end

    # XML namespace values for OAI-PMH Dublin Core containers
    # Used for the ListSets description, see:
    # http://www.openarchives.org/OAI/openarchivesprotocol.html#ListSets
    def oai_dc_xmlns
      {
        'xmlns:oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/',
        'xmlns:dc' => 'http://purl.org/dc/elements/1.1/',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd'
      }
    end

    # XML namespace values for OAI Identifier schema
    # Used for the Identify description, see:
    # http://www.openarchives.org/OAI/openarchivesprotocol.html#Identify
    def oai_id_xmlns
      {
        'xmlns' => 'http://www.openarchives.org/OAI/2.0/oai-identifier/',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/oai-identifier http://www.openarchives.org/OAI/2.0/oai-identifier.xsd'
      }
    end
  end
end
