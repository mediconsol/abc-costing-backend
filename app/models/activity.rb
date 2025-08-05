class Activity < ApplicationRecord
  include HospitalScoped
  include PeriodScoped
  
  # 관계
  belongs_to :department, optional: true
  has_many :account_activity_mappings, dependent: :destroy
  has_many :accounts, through: :account_activity_mappings
  has_many :activity_process_mappings, dependent: :destroy
  has_many :processes, through: :activity_process_mappings
  has_many :work_ratios, dependent: :destroy
  has_many :employees, through: :work_ratios
  
  # 검증
  validates :code, presence: true
  validates :name, presence: true
  validates :category, presence: true
  validates :code, uniqueness: { scope: [:hospital_id, :period_id] }
  
  validate :department_belongs_to_same_hospital_and_period
  
  # 스코프
  scope :by_category, ->(category) { where(category: category) }
  scope :by_department, ->(department_id) { where(department_id: department_id) }
  scope :with_department, -> { where.not(department_id: nil) }
  scope :without_department, -> { where(department_id: nil) }
  scope :mapped_to_accounts, -> { joins(:account_activity_mappings).distinct }
  scope :unmapped, -> { left_joins(:account_activity_mappings).where(account_activity_mappings: { id: nil }) }
  
  # 메서드
  def allocated_cost
    # 계정에서 배분받은 총 원가
    account_activity_mappings.sum do |mapping|
      mapping.account.total_cost * mapping.ratio
    end
  end
  
  def total_fte
    work_ratios.sum(:fte)
  end
  
  def total_hours
    work_ratios.sum(:hours)
  end
  
  def average_hourly_rate
    return 0 if total_hours.zero?
    allocated_cost / total_hours
  end
  
  def unit_cost
    return 0 if total_fte.zero?
    allocated_cost / total_fte
  end
  
  def mapped_accounts_count
    accounts.count
  end
  
  def mapped_processes_count
    processes.count
  end
  
  def assigned_employees_count
    employees.distinct.count
  end
  
  def has_account_mappings?
    account_activity_mappings.exists?
  end
  
  def has_process_mappings?
    activity_process_mappings.exists?
  end
  
  def has_employee_assignments?
    work_ratios.exists?
  end
  
  def department_name
    department&.name || 'N/A'
  end
  
  def display_name
    "#{code} - #{name}"
  end
  
  def full_name
    department ? "#{department.name} > #{name}" : name
  end
  
  # 분석 메서드
  def cost_efficiency
    return 0 if total_fte.zero?
    # 효율성 = 배분된 원가 / FTE (낮을수록 효율적)
    allocated_cost / total_fte
  end
  
  def workload_balance
    # 업무 균형도 = 표준편차 / 평균 (낮을수록 균형적)
    return 0 if work_ratios.empty?
    
    ratios = work_ratios.pluck(:ratio)
    mean = ratios.sum / ratios.size
    variance = ratios.sum { |r| (r - mean) ** 2 } / ratios.size
    Math.sqrt(variance) / mean
  end
  
  private
  
  def department_belongs_to_same_hospital_and_period
    return unless department
    
    unless department.hospital_id == hospital_id && department.period_id == period_id
      errors.add(:department, '부서는 같은 병원과 기간에 속해야 합니다')
    end
  end
end