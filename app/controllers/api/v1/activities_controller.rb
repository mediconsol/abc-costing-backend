class Api::V1::ActivitiesController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_activity, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/activities
  def index
    @activities = @period.activities.includes(:department, :accounts)
    
    # 필터링
    @activities = @activities.where(category: params[:category]) if params[:category].present?
    @activities = @activities.where(department_id: params[:department_id]) if params[:department_id].present?
    @activities = @activities.with_department if params[:with_department] == 'true'
    @activities = @activities.without_department if params[:without_department] == 'true'
    @activities = @activities.mapped_to_accounts if params[:mapped_only] == 'true'
    @activities = @activities.unmapped if params[:unmapped_only] == 'true'
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @activities = @activities.where('code ILIKE ? OR name ILIKE ?', search_term, search_term)
    end
    
    # 정렬
    @activities = @activities.order(:code)
    
    render_success({
      activities: @activities.map { |activity| activity_data(activity) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/activities/:id
  def show
    render_success({
      activity: activity_data(@activity, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/activities
  def create
    @activity = @period.activities.build(activity_params)
    @activity.hospital = current_hospital
    
    if @activity.save
      render_success({
        activity: activity_data(@activity)
      }, 'Activity created successfully', :created)
    else
      render_error('Activity creation failed', :unprocessable_entity, @activity.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/activities/:id
  def update
    if @activity.update(activity_params)
      render_success({
        activity: activity_data(@activity)
      }, 'Activity updated successfully')
    else
      render_error('Activity update failed', :unprocessable_entity, @activity.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/activities/:id
  def destroy
    if @activity.account_activity_mappings.any?
      render_error('Cannot delete activity with account mappings', :unprocessable_entity)
      return
    end
    
    if @activity.work_ratios.any?
      render_error('Cannot delete activity with work ratio assignments', :unprocessable_entity)
      return
    end
    
    @activity.destroy
    render_success(nil, 'Activity deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_activity
    @activity = @period.activities.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Activity not found', :not_found)
  end
  
  def activity_params
    params.require(:activity).permit(:code, :name, :category, :department_id, :description)
  end
  
  def activity_data(activity, include_details: false)
    data = {
      id: activity.id,
      code: activity.code,
      name: activity.name,
      category: activity.category,
      description: activity.description,
      department_id: activity.department_id,
      display_name: activity.display_name,
      full_name: activity.full_name,
      department_name: activity.department_name,
      mapped_accounts_count: activity.mapped_accounts_count,
      mapped_processes_count: activity.mapped_processes_count,
      assigned_employees_count: activity.assigned_employees_count,
      has_account_mappings: activity.has_account_mappings?,
      has_process_mappings: activity.has_process_mappings?,
      has_employee_assignments: activity.has_employee_assignments?,
      hospital_id: activity.hospital_id,
      period_id: activity.period_id,
      created_at: activity.created_at,
      updated_at: activity.updated_at
    }
    
    if include_details
      data.merge!({
        allocated_cost: activity.allocated_cost,
        total_fte: activity.total_fte,
        total_hours: activity.total_hours,
        average_hourly_rate: activity.average_hourly_rate,
        unit_cost: activity.unit_cost,
        cost_efficiency: activity.cost_efficiency,
        workload_balance: activity.workload_balance,
        department: activity.department ? {
          id: activity.department.id,
          code: activity.department.code,
          name: activity.department.name,
          department_type: activity.department.department_type
        } : nil,
        mapped_accounts: activity.accounts.map do |account|
          {
            id: account.id,
            code: account.code,
            name: account.name,
            category: account.category
          }
        end
      })
    end
    
    data
  end
end