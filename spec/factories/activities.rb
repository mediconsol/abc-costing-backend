FactoryBot.define do
  factory :activity do
    association :hospital
    association :period
    association :department
    sequence(:code) { |n| "ACT#{n.to_s.rjust(4, '0')}" }
    sequence(:name) { |n| "Activity #{n}" }
    category { 'clinical' }
    description { "Standard clinical activity" }
    
    # Cost fields with defaults
    allocated_cost { 0 }
    employee_cost { 0 }
    total_cost { 0 }
    total_fte { 0 }
    total_hours { 0 }
    average_hourly_rate { 0 }
    unit_cost { 0 }
    
    trait :clinical do
      category { 'clinical' }
    end
    
    trait :administrative do
      category { 'administrative' }
    end
    
    trait :support do
      category { 'support' }
    end
    
    trait :with_costs do
      allocated_cost { rand(50000..200000) }
      employee_cost { rand(30000..100000) }
      total_fte { rand(2.0..8.0).round(2) }
      total_hours { rand(4000..16000) }
      average_hourly_rate { rand(25.0..75.0).round(2) }
      unit_cost { rand(50.0..500.0).round(2) }
      
      # Calculate total cost
      after(:build) do |activity|
        activity.total_cost = activity.allocated_cost + activity.employee_cost
      end
    end
    
    trait :with_account_mappings do
      after(:create) do |activity|
        account = create(:account, 
          hospital: activity.hospital, 
          period: activity.period
        )
        
        create(:account_activity_mapping,
          hospital: activity.hospital,
          period: activity.period,
          account: account,
          activity: activity,
          ratio: 1.0
        )
      end
    end
    
    trait :with_process_mappings do
      after(:create) do |activity|
        processes = create_list(:process, 2,
          hospital: activity.hospital,
          period: activity.period,
          activity: activity
        )
        
        processes.each_with_index do |process, index|
          create(:activity_process_mapping,
            hospital: activity.hospital,
            period: activity.period,
            activity: activity,
            process: process,
            rate: 0.5
          )
        end
      end
    end
    
    trait :with_employees do
      after(:create) do |activity|
        employees = create_list(:employee, 3,
          hospital: activity.hospital,
          period: activity.period,
          department: activity.department
        )
        
        employees.each do |employee|
          create(:work_ratio,
            hospital: activity.hospital,
            period: activity.period,
            employee: employee,
            activity: activity,
            ratio: rand(0.2..0.8).round(2),
            hours_per_period: rand(500..1500)
          )
        end
      end
    end
    
    trait :fully_configured do
      with_costs
      with_account_mappings
      with_process_mappings
      with_employees
    end
  end
end