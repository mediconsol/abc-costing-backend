class AccountSerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :id, :code, :name, :category, :is_direct, :description, :created_at, :updated_at
  
  attribute :hospital_id do |account|
    account.hospital_id
  end
  
  attribute :period_id do |account|
    account.period_id
  end
  
  attribute :display_name do |account|
    account.display_name
  end
  
  attribute :category_humanized do |account|
    account.category_humanized
  end
  
  attribute :mapped_activities_count do |account|
    account.mapped_activities_count
  end
  
  attribute :has_mappings do |account|
    account.has_mappings?
  end
  
  belongs_to :hospital, serializer: :hospital
  belongs_to :period, serializer: :period
  has_many :activities, through: :account_activity_mappings, serializer: :activity
end