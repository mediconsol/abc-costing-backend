class Api::V1::Reports::DepartmentsController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/departments
  def index
    # Check if ABC calculation is completed
    unless @period.calculation_status == 'completed'
      render_error('ABC calculation must be completed before generating department reports', :precondition_failed)
      return
    end
    
    @departments = @period.departments.includes(:activities, :employees, :parent, :children)
    
    # 필터링
    @departments = @departments.where(department_type: params[:type]) if params[:type].present?
    @departments = @departments.where(parent_id: params[:parent_id]) if params[:parent_id].present?
    @departments = @departments.root_departments if params[:root_only] == 'true'
    
    # 정렬
    sort_field = params[:sort] || 'total_cost'
    sort_direction = params[:direction] || 'desc'
    
    case sort_field
    when 'total_cost'
      @departments = @departments.joins(:activities).group('departments.id').order("SUM(activities.total_cost) #{sort_direction}")
    when 'name'
      @departments = @departments.order("name #{sort_direction}")
    when 'code'
      @departments = @departments.order("code #{sort_direction}")
    else
      @departments = @departments.order(:code)
    end
    
    render_success({
      departments: @departments.map { |dept| department_report_data(dept) },
      summary: department_summary,
      period_info: period_info
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/departments/:id
  def show
    @department = @period.departments.find(params[:id])
    
    render_success({
      department: detailed_department_data(@department),
      cost_breakdown: department_cost_breakdown(@department),
      activity_analysis: department_activity_analysis(@department),
      employee_analysis: department_employee_analysis(@department),
      efficiency_metrics: department_efficiency_metrics(@department)
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/departments/cost_analysis
  def cost_analysis
    departments = @period.departments.includes(:activities, :employees)
    
    analysis = {
      cost_distribution: cost_distribution_analysis(departments),
      department_rankings: department_rankings(departments),
      cost_efficiency: cost_efficiency_analysis(departments),
      variance_analysis: cost_variance_analysis(departments)
    }
    
    render_success(analysis)
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/departments/hierarchy
  def hierarchy
    root_departments = @period.departments.root_departments.includes(:children, :activities, :employees)
    
    hierarchy = root_departments.map do |dept|
      build_department_hierarchy(dept)
    end
    
    render_success({
      hierarchy: hierarchy,
      summary: {
        total_departments: @period.departments.count,
        direct_departments: @period.departments.direct.count,
        indirect_departments: @period.departments.indirect.count,
        root_departments: root_departments.count
      }
    })
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def department_report_data(department)
    activities = department.activities
    employees = department.employees
    
    {
      id: department.id,
      code: department.code,
      name: department.name,
      department_type: department.department_type,
      manager: department.manager,
      level: department.level,
      is_direct: department.direct?,
      parent: department.parent ? {
        id: department.parent.id,
        name: department.parent.name,
        code: department.parent.code
      } : nil,
      cost_metrics: {
        total_cost: activities.sum(&:total_cost),
        allocated_cost: activities.sum(&:allocated_cost),
        employee_cost: activities.sum(&:employee_cost),
        cost_per_employee: calculate_cost_per_employee(department),
        cost_percentage: calculate_department_cost_percentage(department)
      },
      activity_metrics: {
        activities_count: activities.count,
        avg_activity_cost: calculate_avg_activity_cost(activities),
        top_activity: find_top_activity(activities)
      },
      employee_metrics: {
        employees_count: employees.count,
        total_fte: employees.sum(&:fte),
        avg_hourly_rate: calculate_avg_hourly_rate(employees),
        utilization_rate: calculate_utilization_rate(department)
      },
      efficiency_metrics: {
        cost_per_fte: calculate_cost_per_fte(department),
        productivity_score: calculate_productivity_score(department),
        efficiency_ranking: calculate_efficiency_ranking(department)
      }
    }
  end
  
  def detailed_department_data(department)
    department_report_data(department).merge({
      description: department.description,
      children: department.children.map { |child| department_report_data(child) },
      activities: department.activities.map do |activity|
        {
          id: activity.id,
          code: activity.code,
          name: activity.name,
          category: activity.category,
          total_cost: activity.total_cost,
          allocated_cost: activity.allocated_cost,
          employee_cost: activity.employee_cost,
          unit_cost: activity.unit_cost
        }
      end,
      employees: department.employees.map do |employee|
        {
          id: employee.id,
          name: employee.name,
          position: employee.position,
          fte: employee.fte,
          hourly_rate: employee.hourly_rate,
          total_cost: employee.total_cost
        }
      end
    })
  end
  
  def department_cost_breakdown(department)
    activities = department.activities
    
    {
      by_category: activities.group(:category).sum(&:total_cost),
      by_cost_type: {
        allocated_cost: activities.sum(&:allocated_cost),
        employee_cost: activities.sum(&:employee_cost)
      },
      monthly_trend: calculate_monthly_cost_trend(department),
      cost_drivers: identify_cost_drivers(department)
    }
  end
  
  def department_activity_analysis(department)
    activities = department.activities.order(:total_cost => :desc)
    
    {
      top_cost_activities: activities.limit(5).map do |activity|
        {
          name: activity.name,
          code: activity.code,
          total_cost: activity.total_cost,
          percentage: (activity.total_cost / activities.sum(&:total_cost) * 100).round(2)
        }
      end,
      activity_distribution: activities.group(:category).count,
      efficiency_analysis: activities.map do |activity|
        {
          activity: activity.name,
          unit_cost: activity.unit_cost,
          utilization: calculate_activity_utilization(activity)
        }
      end
    }
  end
  
  def department_employee_analysis(department)
    employees = department.employees
    
    {
      headcount_analysis: {
        total_employees: employees.count,
        total_fte: employees.sum(&:fte),
        avg_fte: employees.average(:fte)&.round(2) || 0
      },
      cost_analysis: {
        total_employee_cost: employees.sum(&:total_cost),
        avg_cost_per_employee: calculate_cost_per_employee(department),
        cost_by_position: employees.group(:position).sum(&:total_cost)
      },
      productivity_metrics: {
        revenue_per_employee: calculate_revenue_per_employee(department),
        workload_distribution: calculate_workload_distribution(department)
      }
    }
  end
  
  def department_efficiency_metrics(department)
    {
      cost_efficiency: {
        cost_per_fte: calculate_cost_per_fte(department),
        cost_per_activity: calculate_cost_per_activity(department),
        efficiency_score: calculate_productivity_score(department)
      },
      benchmarking: {
        ranking: calculate_efficiency_ranking(department),
        peer_comparison: calculate_peer_comparison(department)
      },
      improvement_opportunities: identify_improvement_opportunities(department)
    }
  end
  
  def department_summary
    departments = @period.departments.includes(:activities, :employees)
    total_cost = departments.joins(:activities).sum('activities.total_cost')
    
    {
      total_departments: departments.count,
      total_cost: total_cost,
      avg_cost_per_department: total_cost / [departments.count, 1].max,
      cost_by_type: {
        direct: departments.direct.joins(:activities).sum('activities.total_cost'),
        indirect: departments.indirect.joins(:activities).sum('activities.total_cost')
      },
      top_cost_departments: departments.joins(:activities)
                                      .group('departments.id, departments.name')
                                      .sum('activities.total_cost')
                                      .sort_by { |_, cost| -cost }
                                      .first(5)
                                      .map { |dept_data, cost| { name: dept_data.split(', ').last, cost: cost } }
    }
  end
  
  def period_info
    {
      id: @period.id,
      name: @period.name,
      start_date: @period.start_date,
      end_date: @period.end_date,
      calculation_status: @period.calculation_status,
      last_calculated_at: @period.last_calculated_at
    }
  end
  
  # Helper calculation methods
  def calculate_cost_per_employee(department)
    employees_count = department.employees.count
    return 0 if employees_count == 0
    
    total_cost = department.activities.sum(&:total_cost)
    total_cost / employees_count
  end
  
  def calculate_department_cost_percentage(department)
    department_cost = department.activities.sum(&:total_cost)
    total_period_cost = @period.activities.sum(&:total_cost)
    return 0 if total_period_cost == 0
    
    (department_cost / total_period_cost * 100).round(2)
  end
  
  def calculate_avg_activity_cost(activities)
    return 0 if activities.empty?
    activities.sum(&:total_cost) / activities.count
  end
  
  def find_top_activity(activities)
    top = activities.max_by(&:total_cost)
    return nil unless top
    
    { name: top.name, code: top.code, cost: top.total_cost }
  end
  
  def calculate_avg_hourly_rate(employees)
    return 0 if employees.empty?
    employees.average(:hourly_rate)&.round(2) || 0
  end
  
  def calculate_utilization_rate(department)
    work_ratios = @period.work_ratios.joins(:employee).where(employees: { department: department })
    return 0 if work_ratios.empty?
    
    (work_ratios.average(:ratio) * 100).round(2)
  end
  
  def calculate_cost_per_fte(department)
    total_fte = department.employees.sum(&:fte)
    return 0 if total_fte == 0
    
    total_cost = department.activities.sum(&:total_cost)
    total_cost / total_fte
  end
  
  def calculate_productivity_score(department)
    # Simplified productivity calculation
    cost_efficiency = calculate_cost_per_fte(department)
    utilization = calculate_utilization_rate(department)
    
    return 0 if cost_efficiency == 0
    (utilization / cost_efficiency * 1000).round(2)
  end
  
  def calculate_efficiency_ranking(department)
    # Rank department among peers by productivity score
    departments = @period.departments.where(department_type: department.department_type)
    scores = departments.map { |d| [d.id, calculate_productivity_score(d)] }.sort_by { |_, score| -score }
    rank = scores.find_index { |id, _| id == department.id }
    
    {
      rank: (rank || -1) + 1,
      total: departments.count,
      percentile: rank ? ((departments.count - rank) / departments.count.to_f * 100).round(1) : 0
    }
  end
  
  def build_department_hierarchy(department)
    {
      id: department.id,
      code: department.code,
      name: department.name,
      department_type: department.department_type,
      level: department.level,
      total_cost: department.activities.sum(&:total_cost),
      children: department.children.map { |child| build_department_hierarchy(child) }
    }
  end
  
  # Placeholder methods for complex calculations
  def cost_distribution_analysis(departments)
    { message: "Cost distribution analysis - implementation pending" }
  end
  
  def department_rankings(departments)
    { message: "Department rankings - implementation pending" }
  end
  
  def cost_efficiency_analysis(departments)
    { message: "Cost efficiency analysis - implementation pending" }
  end
  
  def cost_variance_analysis(departments)
    { message: "Cost variance analysis - implementation pending" }
  end
  
  def calculate_monthly_cost_trend(department)
    { message: "Monthly cost trend - implementation pending" }
  end
  
  def identify_cost_drivers(department)
    { message: "Cost drivers identification - implementation pending" }
  end
  
  def calculate_activity_utilization(activity)
    50.0 # Placeholder
  end
  
  def calculate_revenue_per_employee(department)
    0 # Placeholder
  end
  
  def calculate_workload_distribution(department)
    { message: "Workload distribution - implementation pending" }
  end
  
  def calculate_cost_per_activity(department)
    activities_count = department.activities.count
    return 0 if activities_count == 0
    
    department.activities.sum(&:total_cost) / activities_count
  end
  
  def calculate_peer_comparison(department)
    { message: "Peer comparison - implementation pending" }
  end
  
  def identify_improvement_opportunities(department)
    { message: "Improvement opportunities - implementation pending" }
  end
end