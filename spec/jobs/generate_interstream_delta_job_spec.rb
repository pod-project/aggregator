# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateInterstreamDeltaJob do
  let(:organization) { create(:organization) }

  before do
    organization.default_stream.uploads << build(:upload, :binary_marc)
    organization.default_stream.uploads << build(:upload, :long_file)
    organization.default_stream.uploads << build(:upload, :binary_marc)
  end

  it 'Does not create an interstream delta if there is no previous default stream' do
    GenerateFullDumpJob.perform_now(organization)
    described_class.perform_now(organization.default_stream)
    expect(organization.default_stream.current_full_dump.interstream_delta).to be_nil
  end

  it 'Does not create an interstream delta if the current stream is missing a full dump' do
    GenerateFullDumpJob.perform_now(organization)

    stream = create(:stream, organization:, default: true)
    stream.make_default

    described_class.perform_now(organization.default_stream)
    expect(organization.default_stream.current_full_dump.interstream_delta).to be_nil
  end

  # rubocop:disable RSpec/ExampleLength
  it 'Creates an interstream delta with proper additions and deletes' do
    GenerateFullDumpJob.perform_now(organization)

    stream = create(:stream, organization:, default: false)
    organization.default_stream.default = false
    organization.default_stream.save

    stream.make_default

    stream.uploads << build(:upload, :marc_xml2)
    # Organization.find is used because it is loading an older version of the organization with the wrong
    # default stream. Unsure of the best way to 'refresh' so it's pulling the correct default
    GenerateFullDumpJob.perform_now(Organization.find(organization.id))

    described_class.perform_now(stream)

    # Deltas should contain one addition (we find two instances of 'record' in the xml for <record> and </record>)
    xml = stream.current_full_dump.interstream_delta.marcxml.open { |file| File.readlines(file) }.to_s
    expect(xml.scan(/record/).count).to be(2)

    # Deltas should contain two deletions
    deletes = stream.current_full_dump.interstream_delta.deletes.open { |file| File.readlines(file) }
    expect(deletes.count).to be(2)
  end
  # rubocop:enable RSpec/ExampleLength
end
