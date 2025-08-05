FactoryBot.define do
  factory :process do
    association :hospital
    association :period
    association :activity
    sequence(:code) { |n| "PROC#{n.to_s.rjust(4, '0')}" }
    sequence(:name) { |n| "Process #{n}" }
    category { 'clinical' }
    is_billable { true }
    description { "Standard clinical process" }
    
    # Cost fields with defaults
    allocated_cost { 0 }
    total_cost { 0 }
    unit_cost { 0 }
    profit_margin { 0 }
    
    trait :billable do
      is_billable { true }
    end
    
    trait :non_billable do
      is_billable { false }
    end
    
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
      allocated_cost { rand(20000..100000) }
      total_cost { rand(25000..120000) }
      unit_cost { rand(100.0..1000.0).round(2) }
      profit_margin { rand(-10.0..25.0).round(2) }
    end
    
    trait :with_revenue_codes do
      after(:create) do |process|
        create_list(:revenue_code, 3,
          hospital: process.hospital,
          period: process.period,
          process: process,
          price: rand(200..2000)
        )
      end
    end
    
    trait :with_volume_data do
      with_revenue_codes
      
      after(:create) do |process|
        process.revenue_codes.each do |revenue_code|
          12.times do |month|
            create(:volume_data,
              hospital: process.hospital,
              period: process.period,
              revenue_code: revenue_code,
              month: month + 1,
              volume: rand(50..500)
            )
          end
        end
      end
    end
    
    trait :profitable do
      with_costs
      with_revenue_codes
      
      after(:build) do |process|
        # Ensure profitability
        revenue = process.revenue_codes.sum { |rc| rc.price * 100 }
        process.total_cost = revenue * 0.8  # 20% profit margin
        process.profit_margin = 20.0
      end
    end
    
    trait :fully_configured do
      with_costs
      with_volume_data
    end
  end
end