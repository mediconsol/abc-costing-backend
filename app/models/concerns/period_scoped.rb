module PeriodScoped
  extend ActiveSupport::Concern
  
  included do
    belongs_to :period
    
    validates :period_id, presence: true
    
    scope :for_period, ->(period_id) { where(period_id: period_id) }
    scope :for_periods, ->(period_ids) { where(period_id: period_ids) }
    scope :for_active_period, -> { joins(:period).where(periods: { is_active: true }) }
  end
  
  class_methods do
    def period_scoped_uniqueness(attributes)
      validates_uniqueness_of attributes, scope: [:hospital_id, :period_id]
    end
  end
  
  # 인스턴스 메서드
  def hospital
    period.hospital
  end
  
  def hospital_id
    period.hospital_id
  end
end