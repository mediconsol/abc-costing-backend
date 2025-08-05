class Api::V1::ActivityProcessMappingsController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_mapping, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/activity_process_mappings
  def index
    @mappings = @period.activity_process_mappings.includes(:activity, :process, :driver)
    
    # 필터링
    @mappings = @mappings.where(activity_id: params[:activity_id]) if params[:activity_id].present?
    @mappings = @mappings.where(process_id: params[:process_id]) if params[:process_id].present?
    @mappings = @mappings.where(driver_id: params[:driver_id]) if params[:driver_id].present?
    
    # 정렬
    @mappings = @mappings.joins(:activity, :process).order('activities.code, processes.code')
    
    render_success({
      activity_process_mappings: @mappings.map { |mapping| mapping_data(mapping) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/activity_process_mappings/:id
  def show
    render_success({
      activity_process_mapping: mapping_data(@mapping, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/activity_process_mappings
  def create
    @mapping = ActivityProcessMapping.new(mapping_params)
    @mapping.hospital = current_hospital
    @mapping.period = @period
    
    if @mapping.save
      render_success({
        activity_process_mapping: mapping_data(@mapping)
      }, 'Activity-Process mapping created successfully', :created)
    else
      render_error('Activity-Process mapping creation failed', :unprocessable_entity, @mapping.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/activity_process_mappings/:id
  def update
    if @mapping.update(mapping_params)
      render_success({
        activity_process_mapping: mapping_data(@mapping)
      }, 'Activity-Process mapping updated successfully')
    else
      render_error('Activity-Process mapping update failed', :unprocessable_entity, @mapping.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/activity_process_mappings/:id
  def destroy
    @mapping.destroy
    render_success(nil, 'Activity-Process mapping deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_mapping
    @mapping = ActivityProcessMapping.where(hospital: current_hospital, period: @period)
                                    .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Activity-Process mapping not found', :not_found)
  end
  
  def mapping_params
    params.require(:activity_process_mapping).permit(:activity_id, :process_id, :driver_id, :rate)
  end
  
  def mapping_data(mapping, include_details: false)
    data = {
      id: mapping.id,
      activity_id: mapping.activity_id,
      process_id: mapping.process_id,
      driver_id: mapping.driver_id,
      rate: mapping.rate,
      activity_name: mapping.activity_name,
      process_name: mapping.process_name,
      driver_name: mapping.driver_name,
      hospital_id: mapping.hospital_id,
      period_id: mapping.period_id,
      created_at: mapping.created_at,
      updated_at: mapping.updated_at
    }
    
    if include_details
      data.merge!({
        allocated_volume: mapping.allocated_volume,
        calculated_cost: mapping.calculated_cost,
        activity: mapping.activity ? {
          id: mapping.activity.id,
          code: mapping.activity.code,
          name: mapping.activity.name,
          category: mapping.activity.category
        } : nil,
        process: mapping.process ? {
          id: mapping.process.id,
          code: mapping.process.code,
          name: mapping.process.name,
          category: mapping.process.category
        } : nil,
        driver: mapping.driver ? {
          id: mapping.driver.id,
          code: mapping.driver.code,
          name: mapping.driver.name,
          driver_type: mapping.driver.driver_type
        } : nil
      })
    end
    
    data
  end
end