class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
  
  # 관계
  has_many :hospital_users, dependent: :destroy
  has_many :hospitals, through: :hospital_users
  
  # 검증
  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  
  # 스코프
  scope :with_role, ->(role) { joins(:hospital_users).where(hospital_users: { role: role }) }
  scope :for_hospital, ->(hospital_id) { joins(:hospital_users).where(hospital_users: { hospital_id: hospital_id }) }
  
  # 메서드
  def role_for_hospital(hospital)
    hospital_user = hospital_users.find_by(hospital: hospital)
    hospital_user&.role
  end
  
  def admin_for_hospital?(hospital)
    role_for_hospital(hospital) == 'admin'
  end
  
  def manager_for_hospital?(hospital)
    role_for_hospital(hospital) == 'manager'
  end
  
  def viewer_for_hospital?(hospital)
    role_for_hospital(hospital) == 'viewer'
  end
  
  def can_access_hospital?(hospital)
    hospitals.include?(hospital)
  end
  
  def accessible_hospitals
    hospitals
  end
  
  def default_hospital
    hospitals.first
  end
  
  def has_hospitals?
    hospitals.any?
  end
  
  def display_name
    name.presence || email
  end
  
  # JWT 관련
  def jwt_payload
    {
      user_id: id,
      email: email,
      name: name
    }
  end
  
  # 클래스 메서드
  def self.roles_for_select
    {
      '관리자' => 'admin',
      '매니저' => 'manager',
      '조회자' => 'viewer'
    }
  end
end
