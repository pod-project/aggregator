# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'uploads/show' do
  let(:organization) { create(:organization) }

  before do
    stream = Stream.create!(name: 'stream1', organization:, default: true)
    assign(:upload, Upload.create!(
                      name: 'Name',
                      files: [fixture_file_upload(Rails.root.join('spec/fixtures/1297245.marc'), 'application/octet-stream')],
                      stream:
                    ))
    assign(:organization, organization)
    assign(:stream, stream)
  end

  it 'renders attributes' do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/1297245.marc/)
  end
end
