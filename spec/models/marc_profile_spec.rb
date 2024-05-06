# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MarcProfile do
  let(:upload) { create(:upload, :binary_marc) }
  let(:blob) { upload.files.first.blob }

  it 'can be created without an upload' do
    expect { described_class.create(blob:) }.to change(described_class, :count).by(1)
  end
end
