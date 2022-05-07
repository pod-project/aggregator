# frozen_string_literal: true

# Controller to handle streams
class StreamsController < ApplicationController
  load_and_authorize_resource :organization
  load_and_authorize_resource through: :organization, except: %i[make_default]
  skip_authorize_resource only: %i[normalized_dump]
  protect_from_forgery with: :null_session, if: :jwt_token

  def show
    @uploads = @stream.uploads.active.order(created_at: :desc).page(params[:page])
  end

  def resourcelist
    show
    render 'show'
  end

  def new; end

  # GET /organizations/1/streams/2/normalized_data
  def normalized_data; end

  # GET /organizations/1/streams/2/processing_status
  def processing_status; end

  # POST /streams
  # POST /streams.json
  def create
    @stream = Stream.new(stream_params)

    respond_to do |format|
      if @stream.save
        format.html { redirect_to [@organization, @stream], notice: 'Stream was successfully created.' }
        format.json { render :show, status: :created, location: [@organization, @stream] }
      else
        format.html { render :new }
        format.json { render json: @stream.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    begin
      @stream.destroy
    rescue Stream::CannotDestroyStream => e
      notice = e.message
    end

    respond_to do |format|
      format.html { redirect_to organization_streams_path, notice: (notice || 'Stream was successfully destroyed.') }
      format.json { head :no_content }
    end
  end

  def normalized_dump
    authorize! :read, @stream

    @normalized_dump = @stream.normalized_dumps.full_dumps.last || @stream.normalized_dumps.build
  end

  def make_default
    @stream = @organization.streams.find(params[:stream])
    authorize!(:update, @stream)

    begin
      @stream.make_default
    rescue Stream::CannotMakeStreamDefault => e
      notice = e.message
    end

    respond_to do |format|
      format.html { redirect_to @organization, notice: (notice || 'Stream was successfully updated.') }
      format.json { render :show, status: :ok, location: @organization }
    end
  end

  def reanalyze
    ReanalyzeJob.perform_later(@stream)

    respond_to do |format|
      format.html { redirect_back_or_to([@organization, @stream], notice: 'Reanalyze job was successfully enqueued.') }
      format.json { render :show, status: :ok, location: [@organization, @stream] }
    end
  end

  def profile; end

  private

  # Only allow a list of trusted parameters through.
  def stream_params
    params.require(:stream).permit(:name, :slug).merge(organization_id: @organization.id)
  end
end
