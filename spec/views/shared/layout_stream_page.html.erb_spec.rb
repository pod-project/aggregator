# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_layout_stream_page' do
  let(:organization) do
    create(:organization, name: 'Best University')
  end
  let(:stream) { create(:stream_with_uploads, organization:, default: true) }
  let(:user) { create(:user) }

  before do
    assign(:organization, organization)
    assign(:stream, stream)
  end

  it 'links to Manage organization with privileged user in header' do
    allow(view).to receive(:can?).and_return(true)
    render

    expect(view.content_for(:org_header)).to have_link 'Manage organization'
  end

  it 'links to View organization with unprivileged user in header' do
    render

    expect(view.content_for(:org_header)).to have_link 'View organization'
  end
end
