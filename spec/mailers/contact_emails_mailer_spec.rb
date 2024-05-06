# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactEmailsMailer do
  let(:contact_email) { build(:contact_email) }

  describe 'confirm_email' do
    subject(:mail) { described_class.with(contact_email:).confirm_email }

    it 'renders the headers' do
      expect(mail.subject).to eq('Confirm email')
      expect(mail.to).to eq(['test@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('Confirm my account')
    end
  end
end
