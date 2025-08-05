class HospitalSerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :id, :name, :address, :phone, :hospital_type, :created_at, :updated_at
  
  attribute :display_name do |hospital|
    hospital.display_name
  end
  
  attribute :has_active_period do |hospital|
    hospital.has_active_period?
  end
  
  has_many :periods, serializer: :period
  has_many :users, through: :hospital_users, serializer: :user
end