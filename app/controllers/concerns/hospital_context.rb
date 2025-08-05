module HospitalContext
  extend ActiveSupport::Concern
  
  included do
    before_action :set_hospital_context
    before_action :authorize_hospital_access
  end
  
  private
  
  def set_hospital_context
    @current_hospital = find_current_hospital
  end
  
  def find_current_hospital
    hospital_id = params[:hospital_id] || request.headers['X-Hospital-ID']
    
    return nil unless hospital_id
    
    hospital = Hospital.find_by(id: hospital_id)
    return hospital if hospital && current_user.can_access_hospital?(hospital)
    
    nil
  end
  
  def authorize_hospital_access
    unless @current_hospital
      render json: { 
        error: 'Hospital access denied or not specified',
        message: 'Please specify a valid hospital ID in the URL or X-Hospital-ID header'
      }, status: :forbidden
      return false
    end
    
    unless current_user.can_access_hospital?(@current_hospital)
      render json: { 
        error: 'Access denied to this hospital',
        message: 'You do not have permission to access this hospital'
      }, status: :forbidden
      return false
    end
    
    true
  end
  
  def current_hospital
    @current_hospital
  end
  
  def current_user_role
    current_user.role_for_hospital(@current_hospital)
  end
  
  def require_admin!
    unless current_user.admin_for_hospital?(@current_hospital)
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end
  
  def require_manager!
    unless current_user.admin_for_hospital?(@current_hospital) || current_user.manager_for_hospital?(@current_hospital)
      render json: { error: 'Manager or Admin access required' }, status: :forbidden
    end
  end
  
  def can_write?
    current_user.admin_for_hospital?(@current_hospital) || current_user.manager_for_hospital?(@current_hospital)
  end
  
  def can_read?
    current_user.can_access_hospital?(@current_hospital)
  end
end