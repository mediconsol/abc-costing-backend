FactoryBot.define do
  factory :revenue_code do
    code { "MyString" }
    name { "MyString" }
    category { "MyString" }
    price { "9.99" }
    description { "MyText" }
    is_active { false }
    hospital { nil }
    period { nil }
    business_process { nil }
  end
end
