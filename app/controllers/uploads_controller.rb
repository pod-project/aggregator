# frozen_string_literal: true

# Controller to handle uploading files to orgs and managing those files
class UploadsController < ApplicationController
  load_and_authorize_resource :organization
  load_and_authorize_resource through: :organization, except: %i[new create]
  load_and_authorize_resource through: :current_stream, only: %i[new create]
  protect_from_forgery with: :null_session, if: :jwt_token
  helper_method :current_stream

  # GET /uploads
  # GET /uploads.json
  def index
    respond_to do |format|
      format.html { @uploads = @uploads.page(index_params[:page]) }
      format.json
    end
  end

  # GET /uploads/1
  # GET /uploads/1.json
  def show; end

  # GET /uploads/new
  def new; end

  # POST /uploads
  # POST /uploads.json
  def create
    respond_to do |format|
      if @upload.save
        format.html { redirect_to [@organization, @upload], notice: 'Upload was successfully created.' }
        format.json { render :show, status: :created, location: [@organization, @upload] }
      else
        format.html { render :new }
        format.json { render json: @upload.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /uploads/1
  # PATCH/PUT /uploads/1.json
  def update
    respond_to do |format|
      if @upload.update(upload_params)
        format.html { redirect_to [@organization, @upload], notice: 'Upload was successfully updated.' }
        format.json { render :show, status: :ok, location: [@organization, @upload] }
      else
        format.html { render :edit }
        format.json { render json: @upload.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /uploads/1
  # DELETE /uploads/1.json
  def destroy
    @upload.destroy
    respond_to do |format|
      format.html { redirect_to organization_uploads_url(@organization), notice: 'Upload was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def info
    @attachment = @upload.files.find(params[:attachment_id])
    @blob = @attachment.blob
    @marc_profile = @upload.marc_profiles.find_by(blob_id: @blob.id) if @blob.id
  end

  def current_stream
    @current_stream ||=
      if params[:stream].present?
        slug = @organization.default_stream.normalize_friendly_id(params[:stream])

        @organization.streams.find_or_create_by(slug:) do |stream|
          stream.name = params[:stream]
        end
      else
        @organization.default_stream
      end
  end

  private

  def create_params
    upload_params.merge(
      user_id: current_ability&.user&.id,
      allowlisted_jwts_id: current_ability&.allowlisted_jwt&.id,
      ip_address: request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
    )
  end

  def index_params
    params.permit(:page)
  end

  # Only allow a list of trusted parameters through.
  def upload_params
    params.require(:upload).permit(:name, :url, files: []).tap do |p|
      p['files']&.reject!(&:blank?)
      p['url']&.strip!
    end
  end
end
