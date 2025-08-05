class Process < ApplicationRecord
  include HospitalScoped
  include PeriodScoped
  
  # 관계
  belongs_to :hospital
  belongs_to :period
  belongs_to :activity, optional: true
  has_many :revenue_codes, dependent: :destroy
  has_many :activity_process_mappings, dependent: :destroy
  has_many :activities, through: :activity_process_mappings
  has_many :work_ratios, dependent: :destroy
  
  # 검증
  validates :code, presence: true, uniqueness: { scope: [:hospital_id, :period_id] }
  validates :name, presence: true
  validates :category, inclusion: { in: %w[clinical administrative support] }
  validates :is_billable, inclusion: { in: [true, false] }
  
  # 스코프
  scope :billable, -> { where(is_billable: true) }
  scope :non_billable, -> { where(is_billable: false) }
  scope :by_category, ->(category) { where(category: category) }
  
  # 메서드
  def display_name
    "#{code} - #{name}"
  end
  
  def full_name
    category.present? ? "#{name} (#{category.titleize})" : name
  end
  
  def activity_name
    activity&.name
  end
  
  def revenue_codes_count
    revenue_codes.count
  end
  
  def has_revenue_codes?
    revenue_codes.any?
  end
  
  def total_volume
    revenue_codes.joins('LEFT JOIN volume_data ON revenue_codes.id = volume_data.revenue_code_id')
                 .where('volume_data.period_id = ? OR volume_data.period_id IS NULL', period_id)
                 .sum('COALESCE(volume_data.volume, 0)')
  end
  
  def total_revenue
    revenue_codes.joins('LEFT JOIN volume_data ON revenue_codes.id = volume_data.revenue_code_id')
                 .where('volume_data.period_id = ? OR volume_data.period_id IS NULL', period_id)
                 .sum('COALESCE(volume_data.volume, 0) * revenue_codes.price')
  end
  
  def average_price
    return 0 if total_volume == 0
    total_revenue / total_volume
  end
end