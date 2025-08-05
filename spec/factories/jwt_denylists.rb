FactoryBot.define do
  factory :jwt_denylist do
    jti { "MyString" }
    exp { "2025-08-05 10:21:49" }
  end
end
