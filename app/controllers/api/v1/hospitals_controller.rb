class Api::V1::HospitalsController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: []  # 모든 액션에 인증 필요
  
  before_action :set_hospital, only: [:show, :update, :destroy]
  before_action :authorize_hospital_access, only: [:show, :update, :destroy]
  
  # GET /api/v1/hospitals
  def index
    @hospitals = current_user.accessible_hospitals
    
    render_success({
      hospitals: @hospitals.map { |hospital| hospital_data(hospital) }
    })
  end
  
  # GET /api/v1/hospitals/:id
  def show
    render_success({
      hospital: hospital_data(@hospital, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals
  def create
    @hospital = Hospital.new(hospital_params)
    
    if @hospital.save
      # 병원 생성자를 관리자로 등록
      HospitalUser.create!(
        user: current_user,
        hospital: @hospital,
        role: 'admin'
      )
      
      render_success({
        hospital: hospital_data(@hospital)
      }, 'Hospital created successfully', :created)
    else
      render_error('Hospital creation failed', :unprocessable_entity, @hospital.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:id
  def update
    if @hospital.update(hospital_params)
      render_success({
        hospital: hospital_data(@hospital)
      }, 'Hospital updated successfully')
    else
      render_error('Hospital update failed', :unprocessable_entity, @hospital.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:id
  def destroy
    @hospital.destroy
    render_success(nil, 'Hospital deleted successfully')
  end
  
  private
  
  def set_hospital
    @hospital = Hospital.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Hospital not found', :not_found)
  end
  
  def authorize_hospital_access
    unless current_user.can_access_hospital?(@hospital)
      render_error('Access denied to this hospital', :forbidden)
    end
  end
  
  def hospital_params
    params.require(:hospital).permit(:name, :address, :phone, :hospital_type)
  end
  
  def hospital_data(hospital, include_details: false)
    data = {
      id: hospital.id,
      name: hospital.name,
      address: hospital.address,
      phone: hospital.phone,
      hospital_type: hospital.hospital_type,
      display_name: hospital.display_name,
      has_active_period: hospital.has_active_period?,
      user_role: current_user.role_for_hospital(hospital),
      created_at: hospital.created_at,
      updated_at: hospital.updated_at
    }
    
    if include_details
      data.merge!({
        active_period: hospital.active_period&.then do |period|
          {
            id: period.id,
            name: period.name,
            start_date: period.start_date,
            end_date: period.end_date
          }
        end,
        periods_count: hospital.periods.count,
        departments_count: hospital.departments.count,
        accounts_count: hospital.accounts.count,
        activities_count: hospital.activities.count,
        users_count: hospital.users.count
      })
    end
    
    data
  end
end