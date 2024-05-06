# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactEmail do
  subject(:contact_email) { build(:contact_email, organization:) }

  let(:organization) { build(:organization) }

  describe 'changing the email' do
    before do
      contact_email.confirm!
    end

    let!(:old_token) { contact_email.confirmation_token }

    it 'resets the confirmation' do
      contact_email.update(email: 'someone@example.com')
      expect(contact_email.confirmation_token).not_to eq old_token
      expect(contact_email).to have_attributes(confirmed_at: nil, confirmation_sent_at: nil)
    end
  end

  # rubocop:disable RSpec/SubjectStub
  it 'sends a confirmation email' do
    allow(contact_email).to receive(:saved_change_to_attribute?).with(:email).and_return(true)
    expect do
      contact_email.update(email: 'someone@example.com')
    end.to have_enqueued_mail(ContactEmailsMailer, :confirm_email)
  end
  # rubocop:enable RSpec/SubjectStub

  describe '#confirm!' do
    before { contact_email.save }

    it 'adds a confirmed_at value' do
      contact_email.confirm!

      expect(contact_email.confirmed_at).to be_present
    end
  end
end
