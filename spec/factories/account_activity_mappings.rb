FactoryBot.define do
  factory :account_activity_mapping do
    association :hospital
    association :period
    association :account
    association :activity
    ratio { 1.0 }
    
    trait :partial_allocation do
      ratio { rand(0.1..0.9).round(2) }
    end
    
    trait :full_allocation do
      ratio { 1.0 }
    end
    
    # Ensure account and activity belong to the same hospital and period
    after(:build) do |mapping|
      if mapping.account && mapping.activity
        mapping.hospital = mapping.account.hospital
        mapping.period = mapping.account.period
        mapping.activity.hospital = mapping.account.hospital
        mapping.activity.period = mapping.account.period
      end
    end
    
    # Calculate allocated amount
    def allocated_amount
      account.total_cost * ratio
    end
  end
end