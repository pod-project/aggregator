# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Downloading normalzed files from POD' do
  let(:organization) { create(:organization, name: 'Best org', code: 'best-org') }
  let(:user) { create(:user) }

  before do
    login_as(user, scope: :user)

    create_list(:upload, 2, :binary_marc, organization:, stream: organization.default_stream)
  end

  it 'lists organizations' do
    visit organizations_url

    expect(page).to have_link 'Best org'
  end

  it 'lists some limited information about the org' do
    visit organization_url(organization)

    expect(page).to have_no_selector 'h2', text: 'Access Tokens'
    expect(page).to have_no_selector 'h2', text: 'Users'

    expect(page).to have_content '1297245.marc'
    expect(page).to have_no_link 'Download'
  end
end
