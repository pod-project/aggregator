# frozen_string_literal: true

# Controller to handle MarcRecords
class MarcRecordsController < ApplicationController
  load_and_authorize_resource :organization
  load_and_authorize_resource through: :organization
  protect_from_forgery with: :null_session, if: :jwt_token

  def show; end

  def index
    @marc_records = @marc_records.where(marc001: index_params[:marc001]) if index_params[:marc001]
    @marc_records = @marc_records.page(index_params[:page])
  end

  def index_params
    params.permit(:page, :marc001)
  end
end
