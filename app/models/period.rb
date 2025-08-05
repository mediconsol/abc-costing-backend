class Period < ApplicationRecord
  include HospitalScoped
  
  # 관계
  has_many :departments, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :cost_inputs, dependent: :destroy
  has_many :revenue_inputs, dependent: :destroy
  
  # 검증
  validates :name, presence: true
  validates :start_date, :end_date, presence: true
  validates :end_date, comparison: { greater_than: :start_date }
  validates :name, uniqueness: { scope: :hospital_id }
  
  validate :only_one_active_per_hospital, if: :is_active?
  validate :date_range_not_overlap
  
  # 스코프
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current_year, -> { where(start_date: Date.current.beginning_of_year..Date.current.end_of_year) }
  scope :by_year, ->(year) { where(start_date: Date.new(year).beginning_of_year..Date.new(year).end_of_year) }
  
  # 메서드
  def activate!
    transaction do
      hospital.periods.update_all(is_active: false)
      update!(is_active: true)
    end
  end
  
  def deactivate!
    update!(is_active: false)
  end
  
  def duration_days
    (end_date - start_date).to_i + 1
  end
  
  def month_range
    start_date.beginning_of_month..end_date.end_of_month
  end
  
  def overlaps_with?(other_period)
    start_date <= other_period.end_date && end_date >= other_period.start_date
  end
  
  def display_name
    "#{name} (#{start_date.strftime('%Y.%m.%d')} ~ #{end_date.strftime('%Y.%m.%d')})"
  end
  
  private
  
  def only_one_active_per_hospital
    return unless is_active?
    
    active_periods = hospital.periods.active
    active_periods = active_periods.where.not(id: id) if persisted?
    
    if active_periods.exists?
      errors.add(:is_active, '병원당 하나의 활성 기간만 허용됩니다')
    end
  end
  
  def date_range_not_overlap
    return unless start_date && end_date
    
    overlapping = hospital.periods.where.not(id: id)
                         .where('start_date <= ? AND end_date >= ?', end_date, start_date)
    
    if overlapping.exists?
      errors.add(:base, '기간이 다른 기간과 겹칩니다')
    end
  end
end