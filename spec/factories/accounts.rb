FactoryBot.define do
  factory :account do
    association :hospital
    association :period
    sequence(:code) { |n| "ACC#{n.to_s.rjust(4, '0')}" }
    sequence(:name) { |n| "Account #{n}" }
    category { 'salary' }
    is_direct { false }
    description { "Standard account for cost allocation" }
    
    trait :direct do
      is_direct { true }
      category { 'direct_labor' }
    end
    
    trait :indirect do
      is_direct { false }
      category { 'overhead' }
    end
    
    trait :salary do
      category { 'salary' }
    end
    
    trait :supplies do
      category { 'supplies' }
    end
    
    trait :equipment do
      category { 'equipment' }
    end
    
    trait :utilities do
      category { 'utilities' }
    end
    
    trait :with_cost_inputs do
      after(:create) do |account|
        # Create monthly cost inputs
        12.times do |month|
          create(:cost_input,
            hospital: account.hospital,
            period: account.period,
            account: account,
            month: month + 1,
            amount: rand(10000..50000)
          )
        end
      end
    end
    
    trait :with_activity_mappings do
      after(:create) do |account|
        activities = create_list(:activity, 2, 
          hospital: account.hospital, 
          period: account.period
        )
        
        # Create mappings with ratios that sum to 1.0
        create(:account_activity_mapping,
          hospital: account.hospital,
          period: account.period,
          account: account,
          activity: activities.first,
          ratio: 0.6
        )
        
        create(:account_activity_mapping,
          hospital: account.hospital,
          period: account.period,
          account: account,
          activity: activities.second,
          ratio: 0.4
        )
      end
    end
    
    # Calculate total cost from cost inputs
    def total_cost
      cost_inputs.sum(:amount)
    end
  end
end