FactoryBot.define do
  factory :employee do
    employee_id { "MyString" }
    name { "MyString" }
    email { "MyString" }
    position { "MyString" }
    hourly_rate { "9.99" }
    annual_salary { "9.99" }
    fte { "9.99" }
    is_active { false }
    hospital { nil }
    period { nil }
    department { nil }
  end
end
