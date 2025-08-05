class Api::V1::WorkRatiosController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_work_ratio, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/work_ratios
  def index
    @work_ratios = @period.work_ratios.includes(:employee, :activity, :process)
    
    # 필터링
    @work_ratios = @work_ratios.where(employee_id: params[:employee_id]) if params[:employee_id].present?
    @work_ratios = @work_ratios.where(activity_id: params[:activity_id]) if params[:activity_id].present?
    @work_ratios = @work_ratios.where(process_id: params[:process_id]) if params[:process_id].present?
    
    # 정렬
    @work_ratios = @work_ratios.joins(:employee, :activity)
                              .order('employees.employee_id, activities.code')
    
    render_success({
      work_ratios: @work_ratios.map { |work_ratio| work_ratio_data(work_ratio) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/work_ratios/:id
  def show
    render_success({
      work_ratio: work_ratio_data(@work_ratio, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/work_ratios
  def create
    @work_ratio = WorkRatio.new(work_ratio_params)
    @work_ratio.hospital = current_hospital
    @work_ratio.period = @period
    
    if @work_ratio.save
      render_success({
        work_ratio: work_ratio_data(@work_ratio)
      }, 'Work ratio created successfully', :created)
    else
      render_error('Work ratio creation failed', :unprocessable_entity, @work_ratio.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/work_ratios/:id
  def update
    if @work_ratio.update(work_ratio_params)
      render_success({
        work_ratio: work_ratio_data(@work_ratio)
      }, 'Work ratio updated successfully')
    else
      render_error('Work ratio update failed', :unprocessable_entity, @work_ratio.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/work_ratios/:id
  def destroy
    @work_ratio.destroy
    render_success(nil, 'Work ratio deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_work_ratio
    @work_ratio = WorkRatio.where(hospital: current_hospital, period: @period)
                          .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Work ratio not found', :not_found)
  end
  
  def work_ratio_params
    params.require(:work_ratio).permit(:employee_id, :activity_id, :process_id, :ratio, :hours_per_period)
  end
  
  def work_ratio_data(work_ratio, include_details: false)
    data = {
      id: work_ratio.id,
      employee_id: work_ratio.employee_id,
      activity_id: work_ratio.activity_id,
      process_id: work_ratio.process_id,
      ratio: work_ratio.ratio,
      hours_per_period: work_ratio.hours_per_period,
      employee_name: work_ratio.employee_name,
      activity_name: work_ratio.activity_name,
      process_name: work_ratio.process_name,
      hospital_id: work_ratio.hospital_id,
      period_id: work_ratio.period_id,
      created_at: work_ratio.created_at,
      updated_at: work_ratio.updated_at
    }
    
    if include_details
      data.merge!({
        allocated_hours: work_ratio.allocated_hours,
        allocated_cost: work_ratio.allocated_cost,
        percentage: work_ratio.percentage,
        employee: work_ratio.employee ? {
          id: work_ratio.employee.id,
          employee_id: work_ratio.employee.employee_id,
          name: work_ratio.employee.name,
          position: work_ratio.employee.position,
          hourly_rate: work_ratio.employee.hourly_rate
        } : nil,
        activity: work_ratio.activity ? {
          id: work_ratio.activity.id,
          code: work_ratio.activity.code,
          name: work_ratio.activity.name,
          category: work_ratio.activity.category
        } : nil,
        process: work_ratio.process ? {
          id: work_ratio.process.id,
          code: work_ratio.process.code,
          name: work_ratio.process.name,
          category: work_ratio.process.category
        } : nil
      })
    end
    
    data
  end
end