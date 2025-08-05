FactoryBot.define do
  factory :activity_process_mapping do
    rate { "9.99" }
    hospital { nil }
    period { nil }
    activity { nil }
    process { nil }
    driver { nil }
  end
end
