class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  
  # UUID 기본키 설정
  self.abstract_class = true
  
  # 공통 scope 및 메서드
  scope :recent, -> { order(created_at: :desc) }
  
  # UUID 생성 (필요시 오버라이드 가능)
  before_create :generate_uuid, if: -> { self.id.nil? }
  
  private
  
  def generate_uuid
    self.id = SecureRandom.uuid
  end
end
