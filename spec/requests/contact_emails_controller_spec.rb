# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/contact_emails' do
  let(:organization) { create(:organization) }

  describe 'GET /confirm/12345' do
    let(:contact_email) { create(:contact_email, organization:) }

    it 'confirms the contact email' do
      get contact_email_confirmation_url(token: contact_email.confirmation_token)

      contact_email.reload

      expect(contact_email.confirmed_at).to be_present
    end
  end
end
