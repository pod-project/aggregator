# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MarcRecord do
  subject(:marc_record) { described_class.new(marc: record, upload:, **attr) }

  let(:attr) { {} }
  let(:organization) { create(:organization, code: 'COOlCOdE', slug: 'ivy-u') }
  let(:upload) { create(:upload, :binary_marc, organization:) }
  let(:record) do
    MARC::Record.new.tap do |record|
      record.append(MARC::ControlField.new('001', '12345'))
      record.append(MARC::DataField.new('999', ' ', ' ', %w[a NA737.K4], %w[i 36105032407764], %w[m ART]))
    end
  end

  it 'has a unique OAI identifier' do
    expect(marc_record.oai_id).to eq("oai:pod.stanford.edu:ivy-u:#{upload.stream.id}:12345")
  end

  describe '#marc' do
    context 'with serialized json' do
      let(:attr) do
        { marc: MARC::Record.new.tap { |record| record.leader = '123' } }
      end

      it 'gets the MARC record from the serialized json' do
        expect(marc_record.marc.leader).to eq '123'
      end
    end
  end

  describe '#augmented_marc' do
    before do
      organization.update(normalization_steps: { '0' => {
                            destination_tag: '998',
                            source_tag: '999',
                            subfields: { i: 'i', a: 'a', m: 'm' }
                          } })
    end

    it 'adds a $5 to indicate a POD-added field' do
      expect(marc_record.augmented_marc.fields('900').first['5']).to eq 'POD'
    end

    it "applies the Organization's code as the 900$b" do
      expect(marc_record.augmented_marc.fields('900').first['b']).to eq 'COOlCOdE'
    end

    it 'applies the organization normalization steps' do
      field = marc_record.augmented_marc.fields('998').first

      expect(field.subfields.map(&:to_s)).to include('$a NA737.K4 ')
        .and include('$i 36105032407764 ')
        .and include('$m ART ')
    end

    it 'includes provenance linking for derived data' do
      field = marc_record.augmented_marc.fields('998').first

      expect(field['8']).to eq '999.0\p'
    end
  end
end
