# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OaiMarcRecordWriterService do
  subject(:service) { described_class.new('test') }

  it 'tracks the number of records written'
  it 'opens a new file when the count written exceeds the max page size'
  it 'can write a marc records as oai xml'
  it 'can write a delete record as oai xml'
  it 'can attach all files to a dump'
  it 'generates human readable filenames'
end
