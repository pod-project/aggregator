# frozen_string_literal: true

require 'spec_helper'
require 'active_storage_blob_content_types'

RSpec.describe ActiveStorageBlobContentTypes do
  let(:content_type) { nil }
  let(:analyzer) { nil }
  let(:blob_class) do
    Class.new do
      attr_reader :analyzer, :content_type, :metadata

      def initialize(content_type, analyzer)
        @content_type = content_type
        @analyzer = analyzer
        @metadata = {}
      end

      def extract_metadata_via_analyzer
        {
          content_type:
        }
      end

      def update!(args)
        @content_type = args[:content_type]
      end

      include ActiveStorageBlobContentTypes
    end
  end
  let(:test_class) { blob_class.new(content_type, analyzer) }

  describe '#analyze' do
    let(:analyzer) { instance_double('MarcAnalyzer', reader: instance_double('MarcRecordService', identify: :marc21)) }

    it 'updates from marc_content_types' do
      expect(test_class.analyze).to eq 'application/marc'
    end
  end

  describe '#marc_content_type' do
    context 'when type is :marc' do
      let(:analyzer) { instance_double('MarcAnalyzer', reader: instance_double('MarcRecordService', identify: :marc21)) }

      it do
        expect(test_class.marc_content_type)
          .to eq 'application/marc'
      end
    end

    context 'when type is :marcxml' do
      let(:analyzer) { instance_double('MarcAnalyzer', reader: instance_double('MarcRecordService', identify: :marcxml)) }

      it do
        expect(test_class.marc_content_type)
          .to eq 'application/marcxml+xml'
      end
    end

    context 'when type is :marcxml_gzip' do
      let(:content_type) { 'application/gzip' }
      let(:analyzer) { instance_double('MarcAnalyzer', reader: instance_double('MarcRecordService', identify: :marcxml_gzip)) }

      it do
        expect(test_class.marc_content_type)
          .to eq 'application/gzip'
      end
    end
  end
end
