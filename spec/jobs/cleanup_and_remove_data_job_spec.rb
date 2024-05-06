# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CleanupAndRemoveDataJob do
  let(:organization) { create(:organization) }

  describe 'archives older streams for an organization after a quarter of not being updated' do
    before do
      organization.default_stream
      Timecop.travel(4.months.ago)
      create_list(:stream, 4, organization:)
      Timecop.return
    end

    it do
      expect { described_class.perform_now(organization) }.to change { organization.streams.active.count }.by(-4)
    end
  end

  describe 'removes streams for an organization after 6 months of not being updated' do
    before do
      organization.default_stream
      Timecop.travel(7.months.ago)
      create_list(:stream, 4, organization:, status: 'archived')
      Timecop.return
    end

    it do
      expect { described_class.perform_now(organization) }.to change { organization.streams.count }.by(-4)
    end
  end

  describe 'removes all but the last two normalized_dumps' do
    before do
      create_list(:normalized_dump, 4, stream: organization.default_stream)
    end

    it do
      expect { described_class.perform_now(organization) }.to change { organization.default_stream.normalized_dumps.count }.by(-2)
    end

    it do
      described_class.perform_now(organization)
      organization.default_stream.normalized_dumps.reload
      expect(organization.default_stream.normalized_dumps.map(&:id)).to eq [3, 4]
    end
  end

  describe '.enqueue_all' do
    it 'enqueues jobs for each organization' do
      expect do
        described_class.enqueue_all
      end.to enqueue_job(described_class).exactly(Organization.count).times
    end
  end
end
