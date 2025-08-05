class PeriodSerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :id, :name, :start_date, :end_date, :is_active, :created_at, :updated_at
  
  attribute :hospital_id do |period|
    period.hospital_id
  end
  
  attribute :display_name do |period|
    period.display_name
  end
  
  attribute :duration_days do |period|
    period.duration_days
  end
  
  belongs_to :hospital, serializer: :hospital
end