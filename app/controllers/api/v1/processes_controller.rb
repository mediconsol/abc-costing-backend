class Api::V1::ProcessesController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_process, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/processes
  def index
    @processes = @period.processes.includes(:activity, :revenue_codes)
    
    # 필터링
    @processes = @processes.where(category: params[:category]) if params[:category].present?
    @processes = @processes.where(activity_id: params[:activity_id]) if params[:activity_id].present?
    @processes = @processes.billable if params[:billable_only] == 'true'
    @processes = @processes.non_billable if params[:non_billable_only] == 'true'
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @processes = @processes.where('code ILIKE ? OR name ILIKE ?', search_term, search_term)
    end
    
    # 정렬
    @processes = @processes.order(:code)
    
    render_success({
      processes: @processes.map { |process| process_data(process) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/processes/:id
  def show
    render_success({
      process: process_data(@process, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/processes
  def create
    @process = @period.processes.build(process_params)
    @process.hospital = current_hospital
    
    if @process.save
      render_success({
        process: process_data(@process)
      }, 'Process created successfully', :created)
    else
      render_error('Process creation failed', :unprocessable_entity, @process.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/processes/:id
  def update
    if @process.update(process_params)
      render_success({
        process: process_data(@process)
      }, 'Process updated successfully')
    else
      render_error('Process update failed', :unprocessable_entity, @process.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/processes/:id
  def destroy
    if @process.activity_process_mappings.any?
      render_error('Cannot delete process with activity mappings', :unprocessable_entity)
      return
    end
    
    if @process.work_ratios.any?
      render_error('Cannot delete process with work ratio assignments', :unprocessable_entity)
      return
    end
    
    @process.destroy
    render_success(nil, 'Process deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_process
    @process = @period.processes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Process not found', :not_found)
  end
  
  def process_params
    params.require(:process).permit(:code, :name, :category, :activity_id, :is_billable, :description)
  end
  
  def process_data(process, include_details: false)
    data = {
      id: process.id,
      code: process.code,
      name: process.name,
      category: process.category,
      is_billable: process.is_billable,
      description: process.description,
      activity_id: process.activity_id,
      display_name: process.display_name,
      full_name: process.full_name,
      activity_name: process.activity_name,
      revenue_codes_count: process.revenue_codes_count,
      has_revenue_codes: process.has_revenue_codes?,
      hospital_id: process.hospital_id,
      period_id: process.period_id,
      created_at: process.created_at,
      updated_at: process.updated_at
    }
    
    if include_details
      data.merge!({
        total_volume: process.total_volume,
        total_revenue: process.total_revenue,
        average_price: process.average_price,
        activity: process.activity ? {
          id: process.activity.id,
          code: process.activity.code,
          name: process.activity.name,
          category: process.activity.category
        } : nil,
        revenue_codes: process.revenue_codes.map do |revenue_code|
          {
            id: revenue_code.id,
            code: revenue_code.code,
            name: revenue_code.name,
            price: revenue_code.price
          }
        end
      })
    end
    
    data
  end
end