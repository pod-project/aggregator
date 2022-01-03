# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateDeltaDumpJob, type: :job do
  let(:organization) { create(:organization) }

  before do
    Timecop.travel(5.days.ago)
    organization.default_stream.uploads << build(:upload, :binary_marc)
    organization.default_stream.uploads << build(:upload, :binary_marc)
    GenerateFullDumpJob.perform_now(organization)

    Timecop.return
    organization.default_stream.uploads << build(:upload, :binary_marc)
  end

  it 'creates a new normalized delta dump' do
    expect do
      described_class.perform_now(organization)
    end.to change { organization.default_stream.reload.current_full_dump.deltas.count }.by(1)
  end

  it 'contains just the new the MARC records from the organization' do
    described_class.perform_now(organization)

    download_and_uncompress(organization.default_stream.reload.current_full_dump.deltas.last.marcxml) do |file|
      expect(Nokogiri::XML(file).xpath('//marc:record', marc: 'http://www.loc.gov/MARC21/slim').count).to eq 1
      expect(file.rewind && file.read).to include '</collection>'
    end
  end

  context 'with deletes' do
    before do
      organization.default_stream.uploads << build(:upload, :deletes)
      organization.default_stream.uploads << build(:upload, :deletes)
    end

    it 'collects deletes into a single file' do
      described_class.perform_now(organization)
      organization.default_stream.reload.current_full_dump.deltas.last.deletes.download do |file|
        expect(file.each_line.count).to eq 4
      end
    end

    it 'does not include MARC records that were deleted' do
      described_class.perform_now(organization)

      expect(organization.default_stream.reload.current_full_dump.deltas.last.marcxml.attachment).to be_nil
    end

    it 'does not include deletes that were readded' do
      organization.default_stream.uploads << build(:upload, :binary_marc)
      described_class.perform_now(organization)

      organization.default_stream.reload.current_full_dump.deltas.last.deletes.download do |file|
        expect(file).not_to include 'a1297245'
      end
    end

    it 'includes MARC records that were re-added' do
      organization.default_stream.uploads << build(:upload, :binary_marc)
      described_class.perform_now(organization)

      download_and_uncompress(organization.default_stream.reload.current_full_dump.deltas.last.marcxml) do |file|
        expect(Nokogiri::XML(file).xpath('//marc:record', marc: 'http://www.loc.gov/MARC21/slim').count).to eq 1
      end
    end
  end

  describe '.enqueue_all' do
    it 'enqueues jobs for each organization' do
      expect do
        described_class.enqueue_all
      end.to enqueue_job(described_class).exactly(Organization.count).times
    end
  end

  def download_and_uncompress(attachment)
    attachment.download do |content|
      yield Zlib::GzipReader.new(StringIO.new(content))
    end
  end
end
