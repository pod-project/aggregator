# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'organizations/organization_details' do
  let(:organization) { create(:organization, name: 'Best University') }
  let(:contact_email) { create(:contact_email, organization:) }

  before do
    assign(:organization, organization)
    assign(:contact_email, contact_email)
  end

  # rubocop:disable RSpec/ExampleLength
  it 'renders form with fields for organization' do
    # this part of the view is seen by org owners and admins
    allow(view).to receive(:can?).and_return(true)
    render
    assert_select 'form[action=?][method=?]', organization_path(organization), 'post' do
      assert_select 'input[name=?]', 'organization[name]'
      assert_select 'input[name=?]', 'organization[slug]'
      assert_select 'input[name=?]', 'organization[code]'
      assert_select 'input[name=?]', 'organization[contact_email_attributes][email]'
    end
  end
  # rubocop:enable RSpec/ExampleLength

  it 'renders provider checkbox on form if creating a new organization' do
    allow(view).to receive(:can?).and_return(true)
    allow(organization).to receive(:new_record?).and_return(true)
    render

    assert_select 'input[name=?]', 'organization[provider]'
  end

  it 'renders a <dl> description list with 4 <dt> description terms' do
    # this part of the view is seen by org memebers
    render

    assert_select 'dl dt', 4
  end
end
