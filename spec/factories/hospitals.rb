FactoryBot.define do
  factory :hospital do
    sequence(:name) { |n| "Hospital #{n}" }
    sequence(:code) { |n| "HSP#{n.to_s.rjust(3, '0')}" }
    address { "123 Medical Center Dr, City, State 12345" }
    phone { "+1-555-123-4567" }
    email { "admin@hospital.com" }
    website { "https://hospital.com" }
    description { "A leading medical institution providing comprehensive healthcare services" }
    is_active { true }
    
    trait :inactive do
      is_active { false }
    end
    
    trait :with_periods do
      after(:create) do |hospital|
        create_list(:period, 2, hospital: hospital)
      end
    end
    
    trait :with_departments do
      after(:create) do |hospital|
        period = create(:period, hospital: hospital)
        create_list(:department, 3, hospital: hospital, period: period)
      end
    end
  end
end