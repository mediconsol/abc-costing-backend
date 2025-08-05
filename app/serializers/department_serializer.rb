class DepartmentSerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :id, :code, :name, :department_type, :manager, :description, :created_at, :updated_at
  
  attribute :hospital_id do |department|
    department.hospital_id
  end
  
  attribute :period_id do |department|
    department.period_id
  end
  
  attribute :parent_id do |department|
    department.parent_id
  end
  
  attribute :full_name do |department|
    department.full_name
  end
  
  attribute :level do |department|
    department.level
  end
  
  attribute :is_direct do |department|
    department.direct?
  end
  
  attribute :is_leaf do |department|
    department.leaf?
  end
  
  belongs_to :hospital, serializer: :hospital
  belongs_to :period, serializer: :period
  belongs_to :parent, serializer: :department, if: Proc.new { |record| record.parent.present? }
  has_many :children, serializer: :department
  has_many :activities, serializer: :activity
end