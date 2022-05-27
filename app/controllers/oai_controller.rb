# frozen_string_literal: true

# Produce OAI-PMH responses
# rubocop:disable Metrics/ClassLength
class OaiController < ApplicationController
  include OaiConcern

  skip_authorization_check
  rescue_from OaiConcern::OaiError, with: :render_error

  def show
    verb = params.require(:verb)
    send("render_#{verb.underscore}")
  rescue ActionController::ParameterMissing
    raise OaiConcern::BadVerb
  end

  def method_missing(method, *_args, &_block)
    raise OaiConcern::BadVerb if method.to_s.start_with?('render_')

    super
  end

  def respond_to_missing?(method, include_private = false)
    method.to_s.start_with?('render_') || super
  end

  private

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def render_list_records
    headers['Cache-Control'] = 'no-cache'
    headers['Last-Modified'] = Time.current.httpdate
    headers['X-Accel-Buffering'] = 'no'

    # token with any other arguments is an error. without a token, metadataPrefix
    # is required and must be 'marc21' since it's all we support. if we don't
    # have a token, construct one to pass to next_record_page.
    if list_records_params[:resumptionToken]
      raise OaiConcern::BadArgument unless list_records_params.except(:verb, :resumptionToken).empty?

      token = OaiConcern::ResumptionToken.decode(list_records_params[:resumptionToken])
    else
      raise OaiConcern::BadArgument unless list_records_params[:metadataPrefix]
      raise OaiConcern::CannotDisseminateFormat unless list_records_params[:metadataPrefix] == 'marc21'

      token = OaiConcern::ResumptionToken.new(
        set: list_records_params[:set],
        from_date: list_records_params[:from],
        until_date: list_records_params[:until]
      )
    end

    render xml: build_list_records_response(*next_record_page(token))
  end

  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  def render_list_sets
    streams = Stream.joins(:default_stream_histories).joins(normalized_dumps: :oai_xml_attachments).distinct
    render xml: build_list_sets_response(streams)
  end

  def render_identify
    earliest_oai = Stream.joins(:default_stream_histories)
                         .joins(normalized_dumps: :oai_xml_attachments)
                         .distinct
                         .order('normalized_dumps.created_at ASC')
                         .limit(1)
                         .pick('normalized_dumps.created_at')

    render xml: build_identify_response(earliest_oai || Time.now.utc)
  end

  def render_list_metadata_formats
    render xml: build_list_metadata_formats_response
  end

  # Render an error response.
  def render_error(exception)
    code = exception.class.name.demodulize.camelize(:lower)

    # Don't render request params for badArgument or badVerb, as per the spec
    if %w[badArgument badVerb].include?(code)
      render xml: build_error_response(code, exception.message)
    else
      render xml: build_error_response(code, exception.message, params.permit!)
    end
  end

  # Return valid OAI-PMH arguments or raise BadArgument if any are invalid.
  def oai_params(*permitted_params)
    raise OaiConcern::BadArgument unless params.except(:controller, :action, *permitted_params).empty?

    params.permit(*permitted_params)
  end

  def list_records_params
    oai_params(:verb, :from, :until, :set, :resumptionToken, :metadataPrefix)
  end

  def list_sets_params
    oai_params(:verb, :resumptionToken)
  end

  def list_metadata_formats_params
    oai_params(:verb, :identifier)
  end

  def identify_params
    oai_params(:verb)
  end

  # rubocop:disable Metrics/AbcSize
  # Get a page of OAI-XML records and a token pointing to the next page
  def next_record_page(token)
    # filter normalized dumps and get the corresponding OAI-XML pages
    # NOTE: each page is guaranteed to have < OAIPMHWriter::max_records_per_file,
    # but some pages will have exactly that number and others won't. The sequence
    # isn't predictable; the only thing we promise is that all pages are less than
    # that size.
    pages = normalized_dumps(token.set, token.from_date, token.until_date).flat_map(&:oai_xml_attachments)
    raise OaiConcern::NoRecordsMatch if pages.empty?

    # generate a token for the next page. no token on the last page, and throw
    # an error if the page number is invalid.
    page = token.page.to_i
    token = if page == pages.length - 1 # last page
              nil
            elsif page < pages.length - 1
              OaiConcern::ResumptionToken.new(set: token.set,
                                              page: page + 1,
                                              from_date: token.from_date,
                                              until_date: token.until_date)
                                         .encode
            else
              raise OaiConcern::BadResumptionToken
            end

    # return the current page and the token for the next page
    [pages[page], token]
  end
  # rubocop:enable Metrics/AbcSize

  # Get NormalizedDumps from a particular stream or created between two dates
  # NOTE: this likely needs work to memoize/tune, but it should be called
  # repeatedly by next_record_page with the same arguments
  def normalized_dumps(set, from_date, until_date)
    # get stream by id, or all default streams if not specified
    streams = if set.present?
                Stream.where(id: set)
              else
                Stream.joins(:default_stream_histories).joins(normalized_dumps: :oai_xml_attachments).distinct
              end

    # get all dumps in this stream, optionally between two dates; error if none
    dumps = filter_dumps(streams, from_date, until_date)
    raise OaiConcern::NoRecordsMatch if dumps.empty?

    dumps
  end

  def filter_dumps(streams, from_date, until_date)
    # get candidate dumps (the current full dump and its deltas for each stream)
    dumps = streams.flat_map(&:current_dumps).sort_by(&:created_at)

    # filter candidate dumps (by from date and until date)
    dumps = dumps.select { |dump| dump.created_at >= Time.zone.parse(from_date).beginning_of_day } if from_date.present?
    dumps = dumps.select { |dump| dump.created_at <= Time.zone.parse(until_date).end_of_day } if until_date.present?

    dumps
  end

  # Wrap the provided Nokogiri::XML::Builder block in an OAI-PMH response
  # See http://www.openarchives.org/OAI/openarchivesprotocol.html#XMLResponse
  def build_oai_response(xml, params)
    xml.send :'OAI-PMH', oai_xmlns do
      xml.responseDate Time.zone.now.iso8601
      xml.request(params.to_hash) do
        xml.text oai_url
      end
      yield xml
    end
  end

  # See https://www.openarchives.org/OAI/openarchivesprotocol.html#ListRecords
  def build_list_records_response(page, token = nil)
    Nokogiri::XML::Builder.new do |xml|
      build_oai_response xml, list_records_params do
        xml.ListRecords do
          read_oai_xml(page) { |data| xml << data }
          if token
            xml.resumptionToken do
              xml.text token
              # NOTE: consider adding completeListSize and cursor (page) here
              # see https://www.openarchives.org/OAI/openarchivesprotocol.html#FlowControl
            end
          end
        end
      end
    end.to_xml
  end

  # See https://www.openarchives.org/OAI/openarchivesprotocol.html#ListSets
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def build_list_sets_response(streams)
    Nokogiri::XML::Builder.new do |xml|
      build_oai_response xml, list_sets_params do
        xml.ListSets do
          streams.each do |stream|
            xml.set do
              xml.setSpec stream.id
              xml.setName "#{stream.organization.slug}, stream #{stream.display_name}"
              xml.setDescription do
                xml[:oai_dc].dc(oai_dc_xmlns) do
                  xml[:dc].description list_sets_description(stream)
                end
              end
            end
          end
        end
      end
    end.to_xml
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  # See https://www.openarchives.org/OAI/openarchivesprotocol.html#Identify
  def build_identify_response(earliest_date)
    Nokogiri::XML::Builder.new do |xml|
      build_oai_response xml, identify_params do
        xml.Identify do
          xml.repositoryName t('layouts.application.title')
          xml.baseURL oai_url
          xml.protocolVersion '2.0'
          xml.earliestDatestamp earliest_date.strftime('%F')
          xml.deletedRecord 'transient'
          xml.granularity 'YYYY-MM-DD'
          xml.adminEmail Settings.contact_email
        end
      end
    end.to_xml
  end

  # See http://www.openarchives.org/OAI/openarchivesprotocol.html#ListMetadataFormats
  def build_list_metadata_formats_response
    Nokogiri::XML::Builder.new do |xml|
      build_oai_response xml, list_metadata_formats_params do
        xml.ListMetadataFormats do
          xml.metadataFormat do
            xml.metadataPrefix 'marc21'
            xml.schema 'http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd'
            xml.metadataNamespace 'http://www.loc.gov/MARC21/slim'
          end
        end
      end
    end.to_xml
  end

  # See http://www.openarchives.org/OAI/openarchivesprotocol.html#ErrorConditions
  def build_error_response(code, message, params = {})
    Nokogiri::XML::Builder.new do |xml|
      build_oai_response xml, params do
        xml.error(code: code) do
          xml.text message
        end
      end
    end.to_xml
  end

  def read_oai_xml(file)
    file.blob.open do |tmpfile|
      io = Zlib::GzipReader.new(tmpfile)
      yield io.read
      io.close
    end
  end
end
# rubocop:enable Metrics/ClassLength
