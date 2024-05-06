# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'organizations/show' do
  before do
    organization = assign(:organization, Organization.create!(
                                           name: 'Name',
                                           slug: 'Slug'
                                         ))

    # create a default stream with some uploads
    stream = Stream.create!(name: 'stream1', organization:, default: true)

    Upload.create!([
                     {
                       name: 'upload1',
                       stream:,
                       url: 'http://example.com/upload1.zip'
                     },
                     {
                       name: 'upload2',
                       stream:,
                       url: 'http://example.com/upload2.zip'
                     }
                   ])

    assign(:uploads, stream.uploads.active.order(created_at: :desc).page(params[:page]))
    assign(:stream, stream)

    sign_in create(:admin)
  end

  it 'renders the stream name' do
    render
    expect(rendered).to match(/stream1/)
  end
end
