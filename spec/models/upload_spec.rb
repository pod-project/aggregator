# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upload, type: :model do
  subject(:upload) { FactoryBot.create(:upload, :binary_marc) }

  describe '#name' do
    it 'has a default name' do
      expect(upload.name).to match(/^\d{4}-\d{2}-\d{2}/)
    end
  end

  describe '#each_marc_record_metadata' do
    context 'with a MARC21 record that has been chunked for length' do
      subject(:upload) { FactoryBot.create(:upload, :marc21_multi_record) }

      let(:record) { upload.each_marc_record_metadata.first.marc }

      it 'merges the record back together' do
        expect(upload.each_marc_record_metadata.count).to eq 1
      end

      it 'has the leader from the first record' do
        expect(record.leader).to eq '02269cas a2200421Ki 45 0'
      end

      it 'de-duplicates fields' do
        expect(record.fields('001').length).to eq 1
        expect(record.fields('001').first.value).to eq 'a9953670'
      end

      it 'merges fields from the second record' do
        expect(record.fields('863').length).to eq 8
      end
    end
  end
end
