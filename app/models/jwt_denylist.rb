class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  self.table_name = 'jwt_denylists'
  
  # 검증
  validates :jti, presence: true, uniqueness: true
  
  # 스코프
  scope :expired, -> { where('exp < ?', Time.current) }
  scope :valid, -> { where('exp >= ?', Time.current) }
  
  # 만료된 토큰 정리
  def self.cleanup_expired
    expired.delete_all
  end
end
