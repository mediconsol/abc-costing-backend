class Account < ApplicationRecord
  include HospitalScoped
  include PeriodScoped
  
  # 관계
  has_many :cost_inputs, dependent: :destroy
  has_many :account_activity_mappings, dependent: :destroy
  has_many :activities, through: :account_activity_mappings
  
  # 검증
  validates :code, presence: true
  validates :name, presence: true
  validates :category, presence: true, inclusion: { 
    in: %w[salary material expense equipment depreciation] 
  }
  validates :code, uniqueness: { scope: [:hospital_id, :period_id] }
  
  # 스코프
  scope :direct, -> { where(is_direct: true) }
  scope :indirect, -> { where(is_direct: false) }
  scope :by_category, ->(category) { where(category: category) }
  scope :salary_accounts, -> { where(category: 'salary') }
  scope :material_accounts, -> { where(category: 'material') }
  scope :expense_accounts, -> { where(category: 'expense') }
  
  # 메서드
  def direct?
    is_direct?
  end
  
  def indirect?
    !is_direct?
  end
  
  def total_cost
    cost_inputs.sum(:amount)
  end
  
  def monthly_costs
    cost_inputs.group(:month).sum(:amount)
  end
  
  def average_monthly_cost
    monthly_costs.values.sum / 12.0
  end
  
  def mapped_activities_count
    activities.count
  end
  
  def has_mappings?
    account_activity_mappings.exists?
  end
  
  def category_humanized
    case category
    when 'salary' then '인건비'
    when 'material' then '재료비'
    when 'expense' then '경비'
    when 'equipment' then '장비비'
    when 'depreciation' then '감가상각비'
    else category
    end
  end
  
  def display_name
    "#{code} - #{name}"
  end
  
  # 클래스 메서드
  def self.categories_for_select
    {
      '인건비' => 'salary',
      '재료비' => 'material', 
      '경비' => 'expense',
      '장비비' => 'equipment',
      '감가상각비' => 'depreciation'
    }
  end
end