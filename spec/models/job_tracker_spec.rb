# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobTracker do
  subject(:job_tracker) do
    described_class.new(attributes.merge(job_class: 'whatever',
                                         job_id:,
                                         provider_job_id:))
  end

  let(:attributes) { {} }
  let(:status_attributes) { { progress: 50, total: 100 } }
  let(:job_id) { 'job_id' }
  let(:provider_job_id) { 'jid' }
  let(:job) { instance_double('job', find_job: 'a job') }
  let(:no_job) { instance_double('job', find_job: nil) }
  let(:retry_set) { no_job }
  let(:dead_set) { no_job }

  before do
    allow(ActiveJob::Status).to receive(:get).with(job_id).and_return(status_attributes)
    allow(Sidekiq::RetrySet).to receive(:new).and_return(retry_set)
    allow(Sidekiq::DeadSet).to receive(:new).and_return(dead_set)
    allow(job).to receive(:size).and_return(1)
    allow(no_job).to receive(:size).and_return(1)
  end

  describe '#status' do
    it 'retrieves the status' do
      expect(job_tracker.status).to eq status_attributes
    end
  end

  describe '#sidekiq_status' do
    context 'when job is in the retry set' do
      let(:retry_set) { job }

      it 'returns retry' do
        expect(job_tracker.sidekiq_status).to eq 'retry'
      end
    end

    context 'when job is in the dead set' do
      let(:dead_set) { job }

      it 'returns dead' do
        expect(job_tracker.sidekiq_status).to eq 'dead'
      end
    end

    context 'when job is in neither the retry nor the dead set' do
      it 'returns active' do
        expect(job_tracker.sidekiq_status).to eq 'active'
      end
    end
  end

  describe '#in_retry_set?' do
    let(:retry_set) { job }

    it 'returns true when the job is in the retry set' do
      expect(job_tracker.in_retry_set?).to be true
    end

    context 'when the job is not in the retry set' do
      let(:retry_set) { no_job }

      it 'returns false' do
        expect(job_tracker.in_retry_set?).to be false
      end
    end

    context 'when there are too many jobs in the set' do
      it 'returns false' do
        allow(job).to receive(:size).and_return(1001)
        expect(job_tracker.in_dead_set?).to be false
      end
    end
  end

  describe '#in_dead_set?' do
    let(:dead_set) { job }

    it 'returns true when the job is in the dead set' do
      expect(job_tracker.in_dead_set?).to be true
    end

    context 'when the job is not in the dead set' do
      let(:dead_set) { no_job }

      it 'returns false' do
        expect(job_tracker.in_dead_set?).to be false
      end
    end

    context 'when there are too many jobs in the set' do
      it 'returns false' do
        allow(job).to receive(:size).and_return(1001)
        expect(job_tracker.in_dead_set?).to be false
      end
    end
  end

  describe '#progress_label' do
    let(:status_attributes) { { progress: 5000, total: 12_345 } }

    it 'returns the current progress' do
      expect(job_tracker.progress_label).to eq '5,000 of 12,345'
    end

    context 'without a final total' do
      let(:status_attributes) { { progress: 5000 } }

      it 'just shows the current progress' do
        expect(job_tracker.progress_label).to eq '5,000'
      end
    end
  end

  describe '#progress' do
    let(:status_attributes) { { progress: 50 } }

    it 'returns the current progress' do
      expect(job_tracker.total).to eq 50
    end
  end

  describe '#total' do
    context 'with no total' do
      let(:status_attributes) { { progress: 50 } }

      it 'returns the current progress' do
        expect(job_tracker.total).to eq 50
      end
    end
  end

  describe '#total?' do
    subject(:total) { job_tracker.total? }

    let(:status_attributes) { { total: 100 } }

    it { is_expected.to be true }

    context 'with an unknown or 0 total' do
      let(:status_attributes) { { total: 0 } }

      it { is_expected.to be false }
    end
  end
end
