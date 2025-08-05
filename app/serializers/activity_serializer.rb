class ActivitySerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :id, :code, :name, :category, :description, :created_at, :updated_at
  
  attribute :hospital_id do |activity|
    activity.hospital_id
  end
  
  attribute :period_id do |activity|
    activity.period_id
  end
  
  attribute :department_id do |activity|
    activity.department_id
  end
  
  attribute :display_name do |activity|
    activity.display_name
  end
  
  attribute :full_name do |activity|
    activity.full_name
  end
  
  attribute :department_name do |activity|
    activity.department_name
  end
  
  attribute :mapped_accounts_count do |activity|
    activity.mapped_accounts_count
  end
  
  attribute :mapped_processes_count do |activity|
    activity.mapped_processes_count
  end
  
  attribute :assigned_employees_count do |activity|
    activity.assigned_employees_count
  end
  
  belongs_to :hospital, serializer: :hospital
  belongs_to :period, serializer: :period
  belongs_to :department, serializer: :department, if: Proc.new { |record| record.department.present? }
  has_many :accounts, through: :account_activity_mappings, serializer: :account
end