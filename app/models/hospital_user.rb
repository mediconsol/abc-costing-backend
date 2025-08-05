class HospitalUser < ApplicationRecord
  # 관계
  belongs_to :user
  belongs_to :hospital
  
  # 검증
  validates :user_id, presence: true
  validates :hospital_id, presence: true
  validates :role, presence: true, inclusion: { in: %w[admin manager viewer] }
  validates :user_id, uniqueness: { scope: :hospital_id }
  
  # 스코프
  scope :admins, -> { where(role: 'admin') }
  scope :managers, -> { where(role: 'manager') }
  scope :viewers, -> { where(role: 'viewer') }
  scope :for_hospital, ->(hospital_id) { where(hospital_id: hospital_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  
  # 메서드
  def admin?
    role == 'admin'
  end
  
  def manager?
    role == 'manager'
  end
  
  def viewer?
    role == 'viewer'
  end
  
  def can_manage?
    admin? || manager?
  end
  
  def can_write?
    admin? || manager?
  end
  
  def can_read?
    true  # 모든 역할은 읽기 가능
  end
  
  def role_humanized
    case role
    when 'admin' then '관리자'
    when 'manager' then '매니저'
    when 'viewer' then '조회자'
    else role
    end
  end
  
  # 클래스 메서드
  def self.roles_for_select
    {
      '관리자' => 'admin',
      '매니저' => 'manager', 
      '조회자' => 'viewer'
    }
  end
  
  def self.create_admin(user, hospital)
    create!(
      user: user,
      hospital: hospital,
      role: 'admin'
    )
  end
  
  def self.create_manager(user, hospital)
    create!(
      user: user,
      hospital: hospital,
      role: 'manager'
    )
  end
  
  def self.create_viewer(user, hospital)
    create!(
      user: user,
      hospital: hospital,
      role: 'viewer'
    )
  end
end