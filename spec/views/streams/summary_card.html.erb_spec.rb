# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'streams/summary_card' do
  let(:organization) { create(:organization, name: 'Best University') }
  let(:stream) { create(:stream_with_uploads, organization:) }
  let(:user) { create(:user) }

  before do
    assign(:organization, organization)
    assign(:stream, stream)
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
  end

  it 'displays Files info' do
    # pass local variable to partial
    render(subject, stream:) # rubocop:disable RSpec/NamedSubject

    expect(rendered).to include(number_with_delimiter(stream.statistic&.file_count || 0))
    expect(rendered).to include('Files')
  end

  it 'displays Total file size info' do
    render(subject, stream:) # rubocop:disable RSpec/NamedSubject

    expect(rendered).to include(number_to_human_size(stream.statistic&.file_size || 0))
    expect(rendered).to include('Total file size')
  end

  it 'displays Records info' do
    render(subject, stream:) # rubocop:disable RSpec/NamedSubject

    expect(rendered).to include(number_with_delimiter(stream.statistic&.record_count || 0))
    expect(rendered).to include('Records')
  end

  it 'displays Unique records info' do
    render(subject, stream:) # rubocop:disable RSpec/NamedSubject

    expect(rendered).to include(number_with_delimiter(stream.statistic&.unique_record_count || 0))
    expect(rendered).to include('Unique records')
  end
end
