FactoryBot.define do
  factory :business_process do
    code { "MyString" }
    name { "MyString" }
    category { "MyString" }
    description { "MyText" }
    is_billable { false }
    hospital { nil }
    period { nil }
    activity { nil }
  end
end
