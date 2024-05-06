# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Downloading normalized files from POD' do
  let(:organization) { create(:organization, code: 'best-org') }
  let(:stream) { create(:stream, organization:, default: true) }
  let(:user) { create(:user) }

  before do
    user.add_role :member, organization
    login_as(user, scope: :user)

    create_list(:upload, 2, :binary_marc, organization:, stream:)
    create_list(:upload, 2, :binary_marc_gz, organization:, stream:)
  end

  describe 'Full dumps' do
    before do
      allow(Time.zone).to receive(:today).and_return('2020-01-01')
      GenerateFullDumpJob.perform_now(organization)
    end

    it 'generates binary & xml full dump files and provides a link to them' do
      visit normalized_data_organization_stream_path(organization, stream)

      expect(page).to have_link "#{organization.slug}-2020-01-01-full-marc21.mrc.gz"
      expect(page).to have_link "#{organization.slug}-2020-01-01-full-marcxml.xml.gz"
    end

    it 'provides all MARC records that have been uploaded to the default stream gzipped into one dump file' do
      visit normalized_data_organization_stream_path(organization, stream)

      # Note, this won't work in a driver other that Rack::Test w/o some other magic
      click_link "#{organization.slug}-2020-01-01-full-marc21.mrc.gz"
      marc = MarcRecordService.marc_reader(StringIO.new(page.body), :marc21_gzip)

      expect(page.response_headers['Content-Disposition']).to eq 'attachment'
      expect(marc.each_raw.count).to eq 1
    end

    it 'provides augmented MARC records with POD and Organizational provenance' do
      visit normalized_data_organization_stream_path(organization, stream)

      # Note, this won't work in a driver other that Rack::Test w/o some other magic
      click_link "#{organization.slug}-2020-01-01-full-marc21.mrc.gz"
      records = MarcRecordService.marc_reader(StringIO.new(page.body), :marc21_gzip)

      records.each do |marc|
        expect(marc['900']['5']).to eq 'POD'
        expect(marc['900']['b']).to eq organization.code
      end
    end

    it 'tracks the download' do
      visit normalized_data_organization_stream_path(organization, stream)

      expect do
        # Note, this won't work in a driver other that Rack::Test w/o some other magic
        click_link "#{organization.slug}-2020-01-01-full-marc21.mrc.gz"
      end.to change(Ahoy::Event, :count).by(1)

      expect(Ahoy::Event.last.properties.with_indifferent_access).to include(
        attachment_name: 'marc21',
        byte_size: 845,
        filename: "#{organization.slug}-2020-01-01-full-marc21.mrc.gz",
        organization_id: organization.slug
      )

      expect(Ahoy::Event.last.visit).to have_attributes(
        organization_id: organization.slug
      )
    end
  end
end
