# frozen_string_literal: true

# Controller to handle uploading files to orgs and managing those files
class UploadsController < ApplicationController
  load_and_authorize_resource :organization
  before_action :load_stream
  authorize_resource :stream
  before_action :load_upload
  authorize_resource through: :stream
  protect_from_forgery with: :null_session, if: :jwt_token

  # GET /uploads
  # GET /uploads.json
  def index; end

  # GET /uploads/1
  # GET /uploads/1.json
  def show; end

  # GET /uploads/new
  def new; end

  # GET /uploads/1/edit
  def edit; end

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

  private

  def load_upload
    @upload = @stream.uploads.find_or_create_by(slug: params[:id]) do |upload|
      upload.name = params[:id]
    end
  end

  def load_stream
    @stream = @organization.default_stream
  end

  # Only allow a list of trusted parameters through.
  def upload_params
    if request.form_data?
      params.require(:upload).permit(:name, :stream_id, files: [])
    elsif request.put?
      {
        name: params[:id],
        files: [{
          io: request.body_stream,
          filename: params[:id],
          content_type: request.content_type
        }]
      }
    end
  end
end
