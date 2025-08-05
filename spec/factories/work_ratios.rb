FactoryBot.define do
  factory :work_ratio do
    ratio { "9.99" }
    hours_per_period { "9.99" }
    hospital { nil }
    period { nil }
    employee { nil }
    activity { nil }
  end
end
