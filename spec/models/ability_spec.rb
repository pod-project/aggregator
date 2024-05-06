# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability do
  subject { described_class.new(user, token) }

  let(:user) { nil }
  let(:token) { nil }

  describe 'for an anonymous user' do
    it { is_expected.to be_able_to(:confirm, ContactEmail) }
  end

  describe 'with a token' do
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let(:default_stream) { create(:stream, :default) }
    let(:token) { { 'jti' => 'anything' } }
    let(:token_attributes) { {} }

    before do
      AllowlistedJwt.create(resource: org1, jti: 'anything', **token_attributes)
    end

    it { is_expected.to be_able_to(:read, org1) }
    it { is_expected.to be_able_to(:read, org2) }

    it { is_expected.to be_able_to(:create, Upload.new(organization: org1)) }
    it { is_expected.not_to be_able_to(:create, Upload.new(organization: org2)) }

    context 'with a token scoped to reads' do
      let(:token_attributes) { { scope: 'download' } }

      it { is_expected.to be_able_to(:read, org1) }
      it { is_expected.to be_able_to(:read, org2) }
      it { is_expected.to be_able_to(:read, create(:upload, :binary_marc, organization: org1)) }
      it { is_expected.to be_able_to(:read, create(:upload, :binary_marc, organization: org2)) }
      it { is_expected.not_to be_able_to(:create, Upload.new(organization: org1)) }
    end

    context 'with a token scoped to upload' do
      let(:token_attributes) { { scope: 'upload' } }

      it { is_expected.to be_able_to(:read, org1) }
      it { is_expected.not_to be_able_to(:read, org2) }
      it { is_expected.to be_able_to(:create, Upload.new(organization: org1)) }
    end
  end

  describe 'with a user' do
    let(:organization) { create(:organization) }
    let(:not_my_org) { create(:organization) }
    let(:default_stream) { create(:stream, :default, organization:) }
    let(:previous_default_stream) { create(:stream, organization:) }

    context 'with an admin' do
      let(:user) { create(:admin) }

      before do
        # add previous_default_stream to the history
        DefaultStreamHistory.create(stream_id: previous_default_stream.id, start_time: '2022-04-15 13:29:21',
                                    end_time: '2022-04-15 13:30:21')
      end

      it { is_expected.to be_able_to(:manage, :all) }
      it { is_expected.not_to be_able_to(:destroy, default_stream) }
      it { is_expected.to be_able_to(:destroy, previous_default_stream) }
    end

    context 'when a user without any roles' do
      let(:user) { User.new }

      it { is_expected.to be_able_to(:read, create(:organization)) }
      it { is_expected.not_to be_able_to(:read, Upload.new) }
      it { is_expected.not_to be_able_to(:read, Stream.new) }
      it { is_expected.not_to be_able_to(:read, AllowlistedJwt.new) }
      it { is_expected.not_to be_able_to(:destroy, default_stream) }
    end

    context 'with an owner of an org' do
      let(:user) { create(:user) }

      before do
        user.add_role :owner, organization
        # add previous_default_stream to the history
        DefaultStreamHistory.create(stream_id: previous_default_stream.id, start_time: '2022-04-15 13:29:21',
                                    end_time: '2022-04-15 13:30:21')
      end

      it { is_expected.not_to be_able_to(:destroy, default_stream) }
      it { is_expected.not_to be_able_to(:destroy, previous_default_stream) }

      # Owner organization
      it { is_expected.to be_able_to(:manage, organization) }
      it { is_expected.not_to be_able_to(:destroy, organization) }

      it { is_expected.to be_able_to(:users, organization) }
      it { is_expected.to be_able_to(:organization_details, organization) }
      it { is_expected.to be_able_to(:provider_details, organization) }

      it { is_expected.to be_able_to(:crud, Upload.new(organization:)) }
      it { is_expected.to be_able_to(:info, Upload.new(organization:)) }

      it { is_expected.to be_able_to(:crud, Stream.new(organization:)) }
      it { is_expected.to be_able_to(:normalized_data, Stream.new(organization:)) }
      it { is_expected.to be_able_to(:processing_status, Stream.new(organization:)) }
      it { is_expected.to be_able_to(:profile, Stream.new(organization:)) }
      it { is_expected.not_to be_able_to(:reanalyze, Stream.new(organization:)) }

      it { is_expected.to be_able_to(:crud, AllowlistedJwt.new(resource: organization)) }

      # Non-member organization
      it { is_expected.not_to be_able_to(:manage, not_my_org) }
      it { is_expected.to be_able_to(:read, not_my_org) }
      it { is_expected.to be_able_to(:users, not_my_org) }
      it { is_expected.to be_able_to(:organization_details, not_my_org) }
      it { is_expected.to be_able_to(:provider_details, not_my_org) }

      it { is_expected.to be_able_to(:read, Upload.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:info, Upload.new(organization: not_my_org)) }
      it { is_expected.not_to be_able_to(:create, Upload.new(organization: not_my_org)) }
      it { is_expected.not_to be_able_to(:destroy, Upload.new(organization: not_my_org)) }

      it { is_expected.to be_able_to(:read, Stream.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:normalized_data, Stream.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:processing_status, Stream.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:profile, Stream.new(organization: not_my_org)) }
      it { is_expected.not_to be_able_to(:create, Stream.new(organization: not_my_org)) }
      it { is_expected.not_to be_able_to(:reanalyze, Stream.new(organization: not_my_org)) }

      it { is_expected.not_to be_able_to(:crud, AllowlistedJwt.new(resource: not_my_org)) }
    end

    context 'with a member of an org' do
      let(:user) { create(:user) }

      before do
        user.add_role :member, organization
      end

      it { is_expected.not_to be_able_to(:destroy, default_stream) }

      # Member organization
      it { is_expected.not_to be_able_to(:manage, organization) }
      it { is_expected.to be_able_to(:read, organization) }
      it { is_expected.to be_able_to(:users, organization) }
      it { is_expected.to be_able_to(:organization_details, organization) }
      it { is_expected.to be_able_to(:provider_details, organization) }

      it { is_expected.to be_able_to(:read, Upload.new(organization:)) }
      it { is_expected.to be_able_to(:info, Upload.new(organization:)) }
      it { is_expected.to be_able_to(:create, Upload.new(organization:)) }
      it { is_expected.not_to be_able_to(:destroy, Upload.new(organization:)) }

      it { is_expected.to be_able_to(:read, Stream.new(organization:)) }
      it { is_expected.to be_able_to(:normalized_data, Stream.new(organization:)) }
      it { is_expected.to be_able_to(:processing_status, Stream.new(organization:)) }
      it { is_expected.to be_able_to(:profile, Stream.new(organization:)) }
      it { is_expected.not_to be_able_to(:create, Stream.new(organization:)) }
      it { is_expected.not_to be_able_to(:reanalyze, Stream.new(organization:)) }

      it { is_expected.to be_able_to(:read, AllowlistedJwt.new(resource: organization)) }
      it { is_expected.not_to be_able_to(:create, AllowlistedJwt.new(resource: organization)) }
      it { is_expected.not_to be_able_to(:update, AllowlistedJwt.new(resource: organization)) }
      it { is_expected.not_to be_able_to(:destroy, AllowlistedJwt.new(resource: organization)) }

      # Non-member organization
      it { is_expected.not_to be_able_to(:manage, not_my_org) }
      it { is_expected.to be_able_to(:read, not_my_org) }
      it { is_expected.to be_able_to(:users, not_my_org) }
      it { is_expected.to be_able_to(:organization_details, not_my_org) }
      it { is_expected.to be_able_to(:provider_details, not_my_org) }

      it { is_expected.to be_able_to(:read, Upload.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:info, Upload.new(organization: not_my_org)) }
      it { is_expected.not_to be_able_to(:create, Upload.new(organization: not_my_org)) }
      it { is_expected.not_to be_able_to(:destroy, Upload.new(organization: not_my_org)) }

      it { is_expected.to be_able_to(:read, Stream.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:normalized_data, Stream.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:processing_status, Stream.new(organization: not_my_org)) }
      it { is_expected.to be_able_to(:profile, Stream.new(organization: not_my_org)) }
      it { is_expected.not_to be_able_to(:create, Stream.new(organization: not_my_org)) }

      it { is_expected.not_to be_able_to(:crud, AllowlistedJwt.new(resource: not_my_org)) }
    end
  end
end
