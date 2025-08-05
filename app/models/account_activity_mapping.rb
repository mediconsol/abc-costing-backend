class AccountActivityMapping < ApplicationRecord
  include HospitalScoped
  include PeriodScoped
  
  # 관계
  belongs_to :account
  belongs_to :activity
  
  # 검증
  validates :ratio, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :account_id, uniqueness: { scope: [:activity_id, :hospital_id, :period_id] }
  
  validate :account_and_activity_same_hospital_period
  validate :total_ratio_not_exceed_one
  
  # 스코프
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_activity, ->(activity_id) { where(activity_id: activity_id) }
  
  # 메서드
  def allocated_amount
    account.total_cost * ratio
  end
  
  def percentage
    (ratio * 100).round(2)
  end
  
  private
  
  def account_and_activity_same_hospital_period
    return unless account && activity
    
    unless account.hospital_id == activity.hospital_id && account.period_id == activity.period_id
      errors.add(:base, 'Account and activity must belong to the same hospital and period')
    end
  end
  
  def total_ratio_not_exceed_one
    return unless account && ratio
    
    total_ratio = account.account_activity_mappings
                         .where.not(id: id)
                         .sum(:ratio) + ratio
    
    if total_ratio > 1.0
      errors.add(:ratio, "Total allocation ratio for account #{account.code} cannot exceed 100%")
    end
  end
end