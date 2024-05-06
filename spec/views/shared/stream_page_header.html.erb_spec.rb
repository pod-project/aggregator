# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_stream_page_header' do
  let(:organization) { create(:organization, name: 'Best University') }
  let(:stream) { create(:stream, organization:) }

  before do
    assign(:organization, organization)
    assign(:stream, stream)
  end

  # rubocop:disable RSpec/MultipleExpectations
  it 'displays the tab links for all users' do
    render

    expect(rendered).to have_link('Uploaded files')
    expect(rendered).to have_link('Normalized data')
    expect(rendered).to have_link('MARC analysis')
    expect(rendered).to have_link('Processing status')
  end
  # rubocop:enable RSpec/MultipleExpectations
end
