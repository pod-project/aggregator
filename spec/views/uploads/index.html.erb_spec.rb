# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'uploads/index' do
  let(:organization) { create(:organization) }
  let(:stream) { create(:stream, organization:) }

  before do
    assign(:organization, organization)
    assign(:stream, stream)
    Upload.create!([
                     {
                       name: 'One',
                       files: [fixture_file_upload(Rails.root.join('spec/fixtures/1297245.marc'), 'application/octet-stream')],
                       stream:
                     },
                     {
                       name: 'Two',
                       files: [fixture_file_upload(Rails.root.join('spec/fixtures/1297245.marc'), 'application/octet-stream')],
                       stream:
                     }
                   ])
    assign(:uploads, stream.uploads.page(params[:page]))
  end

  it 'renders a list of uploads with links to their show pages' do
    render

    expect(rendered).to have_css('tr>td>a', text: 'One', count: 1)
    expect(rendered).to have_css('tr>td>a', text: 'Two', count: 1)
  end

  it 'links to the stream associated with each upload' do
    render

    expect(rendered).to have_css('tr>td>a', text: stream.name, count: 2)
  end

  it 'shows Delete button to privileged users' do
    allow(view).to receive(:can?).and_return(true)
    render

    assert_select 'a.btn', text: 'Delete'
  end
end
