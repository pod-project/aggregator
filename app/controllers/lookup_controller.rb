# frozen_string_literal: true

##
# Controller to lookup MARC records based on standard numbers (e.g. ISBN)
class LookupController < ApplicationController
  skip_authorization_check

  def index
    return {} if index_params[:isbn].blank?

    @response = grouped_marc_records
  end

  def index_params
    params.permit(:isbn)
  end
  helper_method :index_params

  private

  def grouped_marc_records
    MarcRecord.includes(:organization).where(isbn: index_params[:isbn]).group_by(&:organization).select do |org, _|
      can? :read, org
    end
  end
end
