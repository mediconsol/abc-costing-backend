module HospitalScoped
  extend ActiveSupport::Concern
  
  included do
    belongs_to :hospital
    
    validates :hospital_id, presence: true
    
    scope :for_hospital, ->(hospital_id) { where(hospital_id: hospital_id) }
    scope :for_hospitals, ->(hospital_ids) { where(hospital_id: hospital_ids) }
  end
  
  class_methods do
    def hospital_scoped_uniqueness(attributes)
      validates_uniqueness_of attributes, scope: :hospital_id
    end
  end
end