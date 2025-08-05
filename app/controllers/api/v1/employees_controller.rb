class Api::V1::EmployeesController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_employee, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/employees
  def index
    @employees = @period.employees.includes(:department)
    
    # 필터링
    @employees = @employees.where(position: params[:position]) if params[:position].present?
    @employees = @employees.where(department_id: params[:department_id]) if params[:department_id].present?
    @employees = @employees.active if params[:active_only] == 'true'
    @employees = @employees.full_time if params[:full_time_only] == 'true'
    @employees = @employees.part_time if params[:part_time_only] == 'true'
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @employees = @employees.where('employee_id ILIKE ? OR name ILIKE ? OR email ILIKE ?', search_term, search_term, search_term)
    end
    
    # 정렬
    @employees = @employees.order(:employee_id)
    
    render_success({
      employees: @employees.map { |employee| employee_data(employee) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/employees/:id
  def show
    render_success({
      employee: employee_data(@employee, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/employees
  def create
    @employee = @period.employees.build(employee_params)
    @employee.hospital = current_hospital
    
    if @employee.save
      render_success({
        employee: employee_data(@employee)
      }, 'Employee created successfully', :created)
    else
      render_error('Employee creation failed', :unprocessable_entity, @employee.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/employees/:id
  def update
    if @employee.update(employee_params)
      render_success({
        employee: employee_data(@employee)
      }, 'Employee updated successfully')
    else
      render_error('Employee update failed', :unprocessable_entity, @employee.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/employees/:id
  def destroy
    if @employee.work_ratios.any?
      render_error('Cannot delete employee with work ratio assignments', :unprocessable_entity)
      return
    end
    
    @employee.destroy
    render_success(nil, 'Employee deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_employee
    @employee = @period.employees.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Employee not found', :not_found)
  end
  
  def employee_params
    params.require(:employee).permit(:employee_id, :name, :email, :position, :department_id, 
                                     :hourly_rate, :annual_salary, :fte, :is_active)
  end
  
  def employee_data(employee, include_details: false)
    data = {
      id: employee.id,
      employee_id: employee.employee_id,
      name: employee.name,
      email: employee.email,
      position: employee.position,
      hourly_rate: employee.hourly_rate,
      annual_salary: employee.annual_salary,
      fte: employee.fte,
      is_active: employee.is_active,
      department_id: employee.department_id,
      display_name: employee.display_name,
      full_name: employee.full_name,
      department_name: employee.department_name,
      employment_type: employee.employment_type,
      hospital_id: employee.hospital_id,
      period_id: employee.period_id,
      created_at: employee.created_at,
      updated_at: employee.updated_at
    }
    
    if include_details
      data.merge!({
        total_hours: employee.total_hours,
        total_cost: employee.total_cost,
        monthly_cost: employee.monthly_cost,
        weekly_hours: employee.weekly_hours,
        assigned_activities_count: employee.assigned_activities_count,
        workload_utilization: employee.workload_utilization,
        department: employee.department ? {
          id: employee.department.id,
          code: employee.department.code,
          name: employee.department.name,
          department_type: employee.department.department_type
        } : nil,
        assigned_activities: employee.activities.map do |activity|
          {
            id: activity.id,
            code: activity.code,
            name: activity.name,
            category: activity.category
          }
        end
      })
    end
    
    data
  end
end