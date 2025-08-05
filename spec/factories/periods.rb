FactoryBot.define do
  factory :period do
    association :hospital
    sequence(:name) { |n| "FY#{2024 + n}" }
    start_date { Date.current.beginning_of_year }
    end_date { Date.current.end_of_year }
    description { "Annual reporting period" }
    is_active { true }
    calculation_status { 'pending' }
    
    trait :active do
      is_active { true }
    end
    
    trait :inactive do
      is_active { false }
    end
    
    trait :calculated do
      calculation_status { 'completed' }
      last_calculated_at { Time.current }
      calculation_started_at { 1.hour.ago }
      calculation_completed_at { Time.current }
    end
    
    trait :calculating do
      calculation_status { 'in_progress' }
      calculation_started_at { 30.minutes.ago }
    end
    
    trait :failed do
      calculation_status { 'failed' }
      calculation_error { 'Calculation failed due to missing data' }
      calculation_started_at { 1.hour.ago }
      calculation_completed_at { Time.current }
    end
    
    trait :with_departments do
      after(:create) do |period|
        create_list(:department, 3, hospital: period.hospital, period: period)
      end
    end
    
    trait :with_full_setup do
      after(:create) do |period|
        # Create departments
        departments = create_list(:department, 2, hospital: period.hospital, period: period)
        
        # Create accounts
        accounts = create_list(:account, 3, hospital: period.hospital, period: period)
        
        # Create activities
        activities = create_list(:activity, 4, hospital: period.hospital, period: period, department: departments.first)
        
        # Create processes
        create_list(:process, 2, hospital: period.hospital, period: period, activity: activities.first)
        
        # Create employees
        create_list(:employee, 3, hospital: period.hospital, period: period, department: departments.first)
      end
    end
  end
end