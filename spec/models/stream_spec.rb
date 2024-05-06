# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stream do
  subject(:stream) { create(:stream, organization:) }

  let(:organization) { create(:organization) }

  describe '#display_name' do
    it 'defaults to the name of the stream' do
      stream.update(name: 'xyz')
      expect(stream.display_name).to eq 'xyz'
    end

    it 'defaults to the time span' do
      # create Stream manually since factory provides display_name value
      expect(described_class.new(
        organization:,
        created_at: Time.zone.parse('2020-11-01'),
        updated_at: Time.zone.parse('2020-11-05')
      ).display_name).to eq '2020-11-01 - 2020-11-05'
    end

    it 'is open-ended if the stream is the default' do
      # create Stream manually since factory provides display_name value
      expect(described_class.new(
        organization:,
        created_at: Time.zone.parse('2020-11-01'),
        default: true
      ).display_name).to eq '2020-11-01 - '
    end
  end

  describe '#archive' do
    it 'sets status to archived' do
      stream.archive
      expect(stream.status).to eq 'archived'
    end

    it 'archives uploads' do
      organization = create(:organization)
      stream_with_upload = create(:stream_with_uploads, organization:)
      expect { stream_with_upload.archive }.to change { stream_with_upload.uploads.archived.count }.by(1)
    end
  end

  describe '#job_tracker_status_groups' do
    it 'groups the job trackers by status' do
      expect(stream.job_tracker_status_groups).to eq({ active: [], needs_attention: [] })
    end
  end

  describe '#default_stream_histories' do
    it 'creates a default stream history when the first stream is created in an organization' do
      org = create(:organization)
      described_class.create({ organization: org, default: true })
      described_class.create({ organization: org, default: true })
      expect(org.default_stream_histories.count).to be(1)
    end

    it 'creates a new default stream history when stream becomes the default' do
      org = create(:organization)
      described_class.create({ organization: org, default: true })
      second_stream = described_class.create({ organization: org, default: false })

      second_stream.update(default: true)
      expect(DefaultStreamHistory.all[1].end_time).to be_nil
    end

    it 'updates and appends endtime to prior default stream history when the stream is no longer the default' do
      org = create(:organization)
      first_stream = described_class.create({ organization: org, default: true })
      described_class.create({ organization: org, default: false })

      first_stream.update(default: false)
      expect(DefaultStreamHistory.all[0].end_time).not_to be_nil
    end
  end

  describe '#make_default' do
    let!(:current_default) { create(:stream, organization:, default: true) }

    it 'makes the current stream the only default' do
      expect do
        stream.make_default
      end.to(change(stream, :default).from(false).to(true)
         .and((change { current_default.reload.default }).from(true).to(false)))
    end

    it 'does not do anything if the stream is already the default' do
      expect { current_default.make_default }.not_to(change { current_default.reload.default })
    end
  end

  describe '#previous_default_stream_history' do
    let(:org) { create(:organization) }
    let(:stream00) { create(:stream, organization: org, default: true) }
    let(:stream01) { create(:stream, organization: org) }
    let(:stream02) { create(:stream, organization: org) }

    before do
      stream01.reload.make_default
      stream02.reload.make_default
    end

    it 'returns the previous default stream history' do
      expect(stream02.previous_default_stream_history).to eq(stream01.default_stream_histories.first)
    end

    it 'returns nil if there is not a previous default stream history' do
      expect(stream00.previous_default_stream_history).to be_nil
    end

    context 'when the stream has been default more than once' do
      before do
        stream01.reload.make_default
      end

      it 'returns the previous default stream history for the most recent period when a datetime is not supplied' do
        expect(stream01.previous_default_stream_history).to eq(stream02.default_stream_histories.first)
      end

      it 'returns the previous default stream history for the datetime supplied' do
        datetime = stream01.default_stream_histories.first.start_time.strftime('%Y-%m-%d %H:%M:%S.%N')
        expect(stream01.previous_default_stream_history(datetime)).to eq(stream00.default_stream_histories.first)
      end

      it 'returns nil if the datetime supplied is not within a range when the stream has been the default' do
        expect(stream01.previous_default_stream_history('2008-05-10 12:50:35')).to be_nil
      end
    end
  end
end
