# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_layout_manage_organization' do
  let(:is_provider) { true }
  let(:organization) do
    create(:organization, name: 'Best University', provider: is_provider)
  end
  let(:stream) { create(:stream_with_uploads, organization:) }
  let(:user) { create(:user) }

  before do
    assign(:organization, organization)
    assign(:stream, stream)
  end

  it 'links to Provider home for provider orgs' do
    render

    expect(view.content_for(:org_header)).to have_link 'Provider home'
  end

  context 'with a consumer org' do
    let(:is_provider) { false }

    it 'does not link to Provider home for consumer orgs' do
      render

      expect(view.content_for(:org_header)).to have_no_link 'Provider home'
    end
  end
end
