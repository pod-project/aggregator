# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Viewing provider information' do
  let(:organization) { create(:organization, name: 'Best org', code: 'best-org') }
  let(:user) { create(:user) }

  before do
    login_as(user, scope: :user)
    create_list(:upload, 2, :binary_marc, organization:, stream: organization.default_stream)
  end

  describe 'Providers overview page as an unprivileged user' do
    it 'allows unprivileged user to see organizations list' do
      visit organizations_url

      expect(page).to have_link 'Best org'
    end

    it 'does not allow unprivileged user to edit, create, or destroy organizations' do
      visit organizations_url

      # don't confuse "Edit" with "Edit Profile" in header nav
      expect(page).to have_no_link('Edit', exact: true)
      expect(page).to have_no_link 'Delete'
      expect(page).to have_no_link 'New Organization'
    end
  end

  describe 'Providers overview page as an admin' do
    it 'allows admin to see organizations list' do
      user.add_role :admin
      visit organizations_url

      expect(page).to have_link 'Best org'
    end

    it 'allows admin to edit, create, or destroy organizations' do
      user.add_role :admin
      visit organizations_url

      # don't confuse "Edit" with "Edit Profile" in header nav
      expect(page).to have_link('Edit', exact: true)
      expect(page).to have_link 'Delete'
      expect(page).to have_link 'New organization'
    end
  end

  describe 'Provider detail page as an unprivileged user' do
    it 'lists some limited information about the org' do
      visit organization_url(organization)

      expect(page).to have_no_selector 'h2', text: 'Access Tokens'
      expect(page).to have_no_selector 'h2', text: 'Users'

      expect(page).to have_content '1297245.marc'
      expect(page).to have_no_link 'Download'
    end
  end

  describe 'Provider detail page as an admin' do
    it 'lists some limited information about the org' do
      user.add_role :admin
      visit organization_url(organization)

      expect(page).to have_content '1297245.marc'
      expect(page).to have_link 'Download'
    end
  end
end
