# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'uploading files to POD' do
  context 'with an organization user' do
    let(:organization) { create(:organization, name: 'Best University') }
    let(:stream) { create(:stream, organization:) }
    let(:user) { create(:user) }

    before do
      user.add_role :owner, organization
      login_as(user, scope: :user)
    end

    it 'allows an org owner to upload a file to the default stream' do
      visit '/'

      click_on 'Best University home'
      click_on 'New upload'
      attach_file('file', Rails.root.join('spec/fixtures/stanford-50.mrc.gz'))
      click_on 'Create upload'

      expect(page).to have_content 'stanford-50.mrc.gz'
      expect(page).to have_content '17.8 KB application/gzip'
    end
  end
end
