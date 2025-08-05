FactoryBot.define do
  factory :driver do
    code { "MyString" }
    name { "MyString" }
    driver_type { "MyString" }
    category { "MyString" }
    unit { "MyString" }
    description { "MyText" }
    is_active { false }
    hospital { nil }
    period { nil }
  end
end
