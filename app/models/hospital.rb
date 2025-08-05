class Hospital < ApplicationRecord
  # 관계
  has_many :periods, dependent: :destroy
  has_many :departments, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :hospital_users, dependent: :destroy
  has_many :users, through: :hospital_users
  
  # 검증
  validates :name, presence: true, uniqueness: true
  validates :hospital_type, inclusion: { 
    in: %w[general_hospital specialty_hospital clinic], 
    allow_blank: true 
  }
  
  # 스코프
  scope :active, -> { joins(:periods).where(periods: { is_active: true }).distinct }
  scope :by_type, ->(type) { where(hospital_type: type) }
  
  # 메서드
  def active_period
    periods.find_by(is_active: true)
  end
  
  def has_active_period?
    periods.exists?(is_active: true)
  end
  
  def display_name
    "#{name} (#{hospital_type&.humanize})"
  end
end