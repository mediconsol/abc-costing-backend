class Department < ApplicationRecord
  include HospitalScoped
  include PeriodScoped
  
  # 관계
  belongs_to :parent, class_name: 'Department', optional: true
  has_many :children, class_name: 'Department', foreign_key: 'parent_id', dependent: :nullify
  has_many :activities, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :cost_inputs, dependent: :destroy
  
  # 검증
  validates :code, presence: true
  validates :name, presence: true
  validates :department_type, presence: true, inclusion: { in: %w[direct indirect] }
  validates :code, uniqueness: { scope: [:hospital_id, :period_id] }
  
  validate :parent_belongs_to_same_hospital_and_period
  validate :no_circular_dependency
  
  # 스코프
  scope :direct, -> { where(department_type: 'direct') }
  scope :indirect, -> { where(department_type: 'indirect') }
  scope :root_departments, -> { where(parent_id: nil) }
  scope :with_children, -> { where(id: Department.select(:parent_id).distinct) }
  scope :without_children, -> { where.not(id: Department.select(:parent_id).distinct) }
  
  # 메서드
  def direct?
    department_type == 'direct'
  end
  
  def indirect?
    department_type == 'indirect'
  end
  
  def root?
    parent_id.nil?
  end
  
  def leaf?
    children.empty?
  end
  
  def ancestors
    return Department.none unless parent
    
    Department.where(id: ancestor_ids)
  end
  
  def descendants
    return Department.none if leaf?
    
    Department.where(id: descendant_ids)
  end
  
  def siblings
    return Department.none unless parent
    
    parent.children.where.not(id: id)
  end
  
  def level
    return 0 unless parent
    parent.level + 1
  end
  
  def full_name
    return name unless parent
    "#{parent.full_name} > #{name}"
  end
  
  def total_cost
    # 자신의 직접비 + 하위 부서들의 총비용
    direct_cost = cost_inputs.sum(:amount)
    indirect_cost = descendants.joins(:cost_inputs).sum('cost_inputs.amount')
    direct_cost + indirect_cost
  end
  
  private
  
  def ancestor_ids
    ids = []
    current = parent
    while current
      ids << current.id
      current = current.parent
    end
    ids
  end
  
  def descendant_ids
    ids = []
    queue = children.to_a
    
    while queue.any?
      current = queue.shift
      ids << current.id
      queue.concat(current.children.to_a)
    end
    
    ids
  end
  
  def parent_belongs_to_same_hospital_and_period
    return unless parent
    
    unless parent.hospital_id == hospital_id && parent.period_id == period_id
      errors.add(:parent, '상위 부서는 같은 병원과 기간에 속해야 합니다')
    end
  end
  
  def no_circular_dependency
    return unless parent
    
    if ancestor_ids.include?(id)
      errors.add(:parent, '순환 참조가 발생합니다')
    end
  end
end