class Api::V1::DriversController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_driver, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/drivers
  def index
    @drivers = @period.drivers
    
    # 필터링
    @drivers = @drivers.where(driver_type: params[:type]) if params[:type].present?
    @drivers = @drivers.where(category: params[:category]) if params[:category].present?
    @drivers = @drivers.active if params[:active_only] == 'true'
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @drivers = @drivers.where('code ILIKE ? OR name ILIKE ?', search_term, search_term)
    end
    
    # 정렬
    @drivers = @drivers.order(:code)
    
    render_success({
      drivers: @drivers.map { |driver| driver_data(driver) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/drivers/:id
  def show
    render_success({
      driver: driver_data(@driver, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/drivers
  def create
    @driver = @period.drivers.build(driver_params)
    @driver.hospital = current_hospital
    
    if @driver.save
      render_success({
        driver: driver_data(@driver)
      }, 'Driver created successfully', :created)
    else
      render_error('Driver creation failed', :unprocessable_entity, @driver.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/drivers/:id
  def update
    if @driver.update(driver_params)
      render_success({
        driver: driver_data(@driver)
      }, 'Driver updated successfully')
    else
      render_error('Driver update failed', :unprocessable_entity, @driver.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/drivers/:id
  def destroy
    if @driver.activity_process_mappings.any?
      render_error('Cannot delete driver with activity-process mappings', :unprocessable_entity)
      return
    end
    
    @driver.destroy
    render_success(nil, 'Driver deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_driver
    @driver = @period.drivers.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Driver not found', :not_found)
  end
  
  def driver_params
    params.require(:driver).permit(:code, :name, :driver_type, :category, :unit, :is_active, :description)
  end
  
  def driver_data(driver, include_details: false)
    data = {
      id: driver.id,
      code: driver.code,
      name: driver.name,
      driver_type: driver.driver_type,
      category: driver.category,
      unit: driver.unit,
      is_active: driver.is_active,
      description: driver.description,
      display_name: driver.display_name,
      full_name: driver.full_name,
      type_humanized: driver.type_humanized,
      hospital_id: driver.hospital_id,
      period_id: driver.period_id,
      created_at: driver.created_at,
      updated_at: driver.updated_at
    }
    
    if include_details
      data.merge!({
        total_volume: driver.total_volume,
        usage_count: driver.usage_count,
        mapped_activities_count: driver.mapped_activities_count,
        mapped_processes_count: driver.mapped_processes_count,
        has_mappings: driver.has_mappings?
      })
    end
    
    data
  end
end