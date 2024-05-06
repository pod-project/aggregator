# frozen_string_literal: true

FactoryBot.define do
  factory :stream do
    sequence(:name) { |n| "stream-#{n}" }
    factory :stream_with_uploads do
      after(:create) do |stream, options = { count: 1 }|
        create_list(:upload, options[:count], :binary_marc, stream:)
      end
    end

    trait :default do
      default { true }
    end
  end
end
