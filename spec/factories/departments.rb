FactoryBot.define do
  factory :department do
    association :hospital
    association :period
    sequence(:code) { |n| "DEPT#{n.to_s.rjust(3, '0')}" }
    sequence(:name) { |n| "Department #{n}" }
    department_type { 'direct' }
    manager { "Dr. John Smith" }
    description { "A medical department providing specialized services" }
    level { 1 }
    
    trait :direct do
      department_type { 'direct' }
    end
    
    trait :indirect do
      department_type { 'indirect' }
    end
    
    trait :administrative do
      department_type { 'administrative' }
    end
    
    trait :with_parent do
      after(:build) do |department|
        department.parent = create(:department, 
          hospital: department.hospital, 
          period: department.period,
          level: 0
        )
        department.level = 1
      end
    end
    
    trait :with_children do
      after(:create) do |department|
        create_list(:department, 2, 
          hospital: department.hospital,
          period: department.period,
          parent: department,
          level: department.level + 1
        )
      end
    end
    
    trait :with_activities do
      after(:create) do |department|
        create_list(:activity, 3, 
          hospital: department.hospital,
          period: department.period,
          department: department
        )
      end
    end
    
    trait :with_employees do
      after(:create) do |department|
        create_list(:employee, 5,
          hospital: department.hospital,
          period: department.period,
          department: department
        )
      end
    end
  end
end