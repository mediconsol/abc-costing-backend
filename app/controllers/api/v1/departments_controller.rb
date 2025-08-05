class Api::V1::DepartmentsController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_department, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/departments
  def index
    @departments = @period.departments.includes(:parent, :children, :activities)
    
    # 필터링
    @departments = @departments.where(department_type: params[:type]) if params[:type].present?
    @departments = @departments.where(parent_id: params[:parent_id]) if params[:parent_id].present?
    @departments = @departments.root_departments if params[:root_only] == 'true'
    
    # 정렬
    @departments = @departments.order(:code)
    
    render_success({
      departments: @departments.map { |dept| department_data(dept) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/departments/:id
  def show
    render_success({
      department: department_data(@department, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/departments
  def create
    @department = @period.departments.build(department_params)
    @department.hospital = current_hospital
    
    if @department.save
      render_success({
        department: department_data(@department)
      }, 'Department created successfully', :created)
    else
      render_error('Department creation failed', :unprocessable_entity, @department.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/departments/:id
  def update
    if @department.update(department_params)
      render_success({
        department: department_data(@department)
      }, 'Department updated successfully')
    else
      render_error('Department update failed', :unprocessable_entity, @department.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/departments/:id
  def destroy
    if @department.children.any?
      render_error('Cannot delete department with sub-departments', :unprocessable_entity)
      return
    end
    
    if @department.activities.any?
      render_error('Cannot delete department with activities', :unprocessable_entity)
      return
    end
    
    @department.destroy
    render_success(nil, 'Department deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_department
    @department = @period.departments.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Department not found', :not_found)
  end
  
  def department_params
    params.require(:department).permit(:code, :name, :department_type, :parent_id, :manager, :description)
  end
  
  def department_data(department, include_details: false)
    data = {
      id: department.id,
      code: department.code,
      name: department.name,
      department_type: department.department_type,
      manager: department.manager,
      description: department.description,
      parent_id: department.parent_id,
      full_name: department.full_name,
      level: department.level,
      is_direct: department.direct?,
      is_indirect: department.indirect?,
      is_root: department.root?,
      is_leaf: department.leaf?,
      hospital_id: department.hospital_id,
      period_id: department.period_id,
      created_at: department.created_at,
      updated_at: department.updated_at
    }
    
    if include_details
      data.merge!({
        children: department.children.map { |child| department_data(child) },
        activities_count: department.activities.count,
        employees_count: department.employees.count,
        total_cost: department.total_cost,
        parent: department.parent ? department_data(department.parent) : nil
      })
    end
    
    data
  end
end