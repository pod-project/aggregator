# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/organization/:id/stream' do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:stream) { create(:stream, organization:) }

  before do
    sign_in create(:admin)
  end

  describe 'GET /show' do
    it 'renders a successful response' do
      get resourcelist_organization_stream_path(organization_id: stream.organization.id, id: stream.id)
      expect(response).to be_successful
    end

    it 'has some resourceSync stuff in it' do
      get resourcelist_organization_stream_path(organization_id: stream.organization.id, id: stream.id)
      expect(response.body).to include '<rs:md capability="resourcelist"'
    end
  end

  describe 'GET /new' do
    it 'renders a successful response' do
      get new_organization_stream_url(organization)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    let(:valid_attributes) { { name: 'whatever' } }

    context 'with valid parameters' do
      it 'creates a new Stream' do
        expect do
          post organization_streams_url(organization), params: { stream: valid_attributes }
        end.to change(Stream, :count).by(1)
      end

      it 'redirects to the created upload' do
        post organization_streams_url(organization), params: { stream: valid_attributes }
        expect(response).to redirect_to(organization_stream_url(organization, Stream.last))
      end
    end
  end

  describe 'GET /normalized_dump' do
    it 'renders a successful response' do
      get normalized_resourcelist_organization_stream_path(
        organization_id: stream.organization.id, id: stream.id, flavor: 'marcxml'
      )
      expect(response).to be_successful
    end

    it 'has some resourceSync stuff in it' do
      get normalized_resourcelist_organization_stream_path(
        organization_id: stream.organization.id, id: stream.id, flavor: 'marcxml'
      )
      expect(response.body).to include '<rs:md capability="resourcelist"'
    end
  end

  describe 'POST /make_default' do
    let!(:default_stream) { organization.default_stream }

    it 'toggles on the default attribute for the new stream' do
      post make_default_organization_streams_url(organization_id: stream.organization.id, stream:, format: :html)
      expect(response).to redirect_to(organization_url(stream.organization))
      expect(stream.reload).to have_attributes default: true
    end

    it 'toggles off the default stream for the previous default' do
      post make_default_organization_streams_url(organization_id: stream.organization.id, stream:, format: :html)
      expect(default_stream.reload).to have_attributes default: false
    end
  end

  describe 'DELETE /destroy' do
    before { stream } # Ensure the stream is created before destroying

    it 'destroys the requested stream' do
      expect do
        delete organization_stream_url(organization, stream)
      end.to change(Stream, :count).by(-1)
    end

    it 'redirects to the organizations list' do
      delete organization_stream_url(organization, stream)
      expect(response).to redirect_to(organization_streams_url(organization))
    end
  end

  describe 'POST /reanalyze' do
    let!(:default_stream) { organization.default_stream }

    it 'enqueues a background job to re-analyze the stream content' do
      expect do
        post reanalyze_organization_stream_url(organization, default_stream)
      end.to enqueue_job(ReanalyzeJob).with(default_stream)
    end
  end
end
