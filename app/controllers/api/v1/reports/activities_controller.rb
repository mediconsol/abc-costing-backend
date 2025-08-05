class Api::V1::Reports::ActivitiesController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/activities
  def index
    unless @period.calculation_status == 'completed'
      render_error('ABC calculation must be completed before generating activity reports', :precondition_failed)
      return
    end
    
    @activities = @period.activities.includes(:department, :accounts, :processes, :employees)
    
    # 필터링
    @activities = @activities.where(category: params[:category]) if params[:category].present?
    @activities = @activities.where(department_id: params[:department_id]) if params[:department_id].present?
    @activities = @activities.where('total_cost >= ?', params[:min_cost]) if params[:min_cost].present?
    @activities = @activities.where('total_cost <= ?', params[:max_cost]) if params[:max_cost].present?
    
    # 정렬
    sort_field = params[:sort] || 'total_cost'
    sort_direction = params[:direction] || 'desc'
    
    @activities = case sort_field
                 when 'total_cost'
                   @activities.order("total_cost #{sort_direction}")
                 when 'allocated_cost'
                   @activities.order("allocated_cost #{sort_direction}")
                 when 'employee_cost'
                   @activities.order("employee_cost #{sort_direction}")
                 when 'unit_cost'
                   @activities.order("unit_cost #{sort_direction}")
                 when 'name'
                   @activities.order("name #{sort_direction}")
                 else
                   @activities.order(:code)
                 end
    
    render_success({
      activities: @activities.map { |activity| activity_report_data(activity) },
      summary: activity_summary,
      cost_analysis: activity_cost_analysis,
      period_info: period_info
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/activities/:id
  def show
    @activity = @period.activities.find(params[:id])
    
    render_success({
      activity: detailed_activity_data(@activity),
      cost_breakdown: activity_cost_breakdown(@activity),
      resource_analysis: activity_resource_analysis(@activity),
      process_mapping: activity_process_mapping(@activity),
      efficiency_metrics: activity_efficiency_metrics(@activity),
      benchmarking: activity_benchmarking(@activity)
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/activities/cost_distribution
  def cost_distribution
    activities = @period.activities.includes(:department)
    
    distribution = {
      by_category: cost_by_category(activities),
      by_department: cost_by_department(activities),
      by_cost_type: cost_by_type(activities),
      pareto_analysis: pareto_analysis(activities),
      cost_concentration: cost_concentration_analysis(activities)
    }
    
    render_success(distribution)
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/activities/efficiency
  def efficiency
    activities = @period.activities.includes(:department, :employees, :processes)
    
    efficiency_analysis = {
      unit_cost_analysis: unit_cost_analysis(activities),
      productivity_metrics: productivity_metrics(activities),
      resource_utilization: resource_utilization_analysis(activities),
      benchmarking: efficiency_benchmarking(activities),
      improvement_opportunities: identify_efficiency_improvements(activities)
    }
    
    render_success(efficiency_analysis)
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/activities/performance
  def performance
    activities = @period.activities.includes(:processes, :employees)
    
    performance_metrics = {
      top_performers: top_performing_activities(activities),
      underperformers: underperforming_activities(activities),
      performance_trends: calculate_performance_trends(activities),
      variance_analysis: performance_variance_analysis(activities),
      kpi_dashboard: activity_kpi_dashboard(activities)
    }
    
    render_success(performance_metrics)
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def activity_report_data(activity)
    {
      id: activity.id,
      code: activity.code,
      name: activity.name,
      category: activity.category,
      description: activity.description,
      department: activity.department ? {
        id: activity.department.id,
        name: activity.department.name,
        code: activity.department.code,
        department_type: activity.department.department_type
      } : nil,
      cost_metrics: {
        total_cost: activity.total_cost || 0,
        allocated_cost: activity.allocated_cost || 0,
        employee_cost: activity.employee_cost || 0,
        unit_cost: activity.unit_cost || 0,
        cost_percentage: calculate_activity_cost_percentage(activity)
      },
      resource_metrics: {
        total_fte: activity.total_fte || 0,
        total_hours: activity.total_hours || 0,
        average_hourly_rate: activity.average_hourly_rate || 0,
        mapped_accounts_count: activity.mapped_accounts_count || 0,
        mapped_processes_count: activity.mapped_processes_count || 0,
        assigned_employees_count: activity.assigned_employees_count || 0
      },
      efficiency_metrics: {
        cost_per_hour: calculate_cost_per_hour(activity),
        cost_per_fte: calculate_cost_per_fte(activity),
        productivity_score: calculate_activity_productivity_score(activity),
        utilization_rate: calculate_activity_utilization_rate(activity)
      },
      performance_indicators: {
        has_account_mappings: activity.has_account_mappings?,
        has_process_mappings: activity.has_process_mappings?,
        has_employee_assignments: activity.has_employee_assignments?,
        allocation_completeness: calculate_allocation_completeness(activity)
      }
    }
  end
  
  def detailed_activity_data(activity)
    activity_report_data(activity).merge({
      mapped_accounts: activity.accounts.map do |account|
        mapping = activity.account_activity_mappings.find_by(account: account)
        {
          id: account.id,
          code: account.code,
          name: account.name,
          category: account.category,
          is_direct: account.is_direct,
          ratio: mapping&.ratio || 0,
          allocated_amount: mapping&.allocated_amount || 0
        }
      end,
      mapped_processes: activity.processes.map do |process|
        mapping = activity.activity_process_mappings.find_by(process: process)
        {
          id: process.id,
          code: process.code,
          name: process.name,
          category: process.category,
          is_billable: process.is_billable,
          rate: mapping&.rate || 0,
          driver: mapping&.driver ? {
            id: mapping.driver.id,
            name: mapping.driver.name,
            driver_type: mapping.driver.driver_type
          } : nil
        }
      end,
      assigned_employees: activity.employees.map do |employee|
        work_ratio = @period.work_ratios.find_by(employee: employee, activity: activity)
        {
          id: employee.id,
          name: employee.name,
          position: employee.position,
          fte: employee.fte,
          hourly_rate: employee.hourly_rate,
          ratio: work_ratio&.ratio || 0,
          hours_per_period: work_ratio&.hours_per_period || 0,
          allocated_cost: work_ratio&.allocated_cost || 0
        }
      end
    })
  end
  
  def activity_cost_breakdown(activity)
    {
      cost_sources: {
        from_accounts: activity.allocated_cost || 0,
        from_employees: activity.employee_cost || 0,
        total: activity.total_cost || 0
      },
      account_breakdown: activity.accounts.map do |account|
        mapping = activity.account_activity_mappings.find_by(account: account)
        {
          account_name: account.name,
          account_category: account.category,
          allocated_amount: mapping&.allocated_amount || 0,
          percentage: calculate_account_percentage(activity, mapping&.allocated_amount || 0)
        }
      end,
      employee_breakdown: activity.employees.map do |employee|
        work_ratio = @period.work_ratios.find_by(employee: employee, activity: activity)
        {
          employee_name: employee.name,
          position: employee.position,
          allocated_cost: work_ratio&.allocated_cost || 0,
          percentage: calculate_employee_percentage(activity, work_ratio&.allocated_cost || 0)
        }
      end
    }
  end
  
  def activity_resource_analysis(activity)
    {
      human_resources: {
        total_employees: activity.employees.count,
        total_fte: activity.total_fte || 0,
        total_hours: activity.total_hours || 0,
        avg_utilization: calculate_activity_utilization_rate(activity)
      },
      financial_resources: {
        budget_allocated: activity.allocated_cost || 0,
        actual_spent: activity.total_cost || 0,
        variance: (activity.total_cost || 0) - (activity.allocated_cost || 0),
        variance_percentage: calculate_cost_variance_percentage(activity)
      },
      resource_efficiency: {
        cost_per_hour: calculate_cost_per_hour(activity),
        cost_per_fte: calculate_cost_per_fte(activity),
        resource_utilization_score: calculate_resource_utilization_score(activity)
      }
    }
  end
  
  def activity_process_mapping(activity)
    {
      mapped_processes: activity.processes.count,
      process_distribution: activity.processes.group(:category).count,
      billable_processes: activity.processes.billable.count,
      non_billable_processes: activity.processes.non_billable.count,
      process_details: activity.processes.map do |process|
        mapping = activity.activity_process_mappings.find_by(process: process)
        {
          process_name: process.name,
          category: process.category,
          is_billable: process.is_billable,
          allocation_rate: mapping&.rate || 0,
          allocated_cost: calculate_process_allocated_cost(activity, mapping),
          revenue_potential: calculate_process_revenue_potential(process)
        }
      end
    }
  end
  
  def activity_efficiency_metrics(activity)
    {
      cost_efficiency: {
        unit_cost: activity.unit_cost || 0,
        cost_per_hour: calculate_cost_per_hour(activity),
        cost_per_fte: calculate_cost_per_fte(activity)
      },
      productivity_metrics: {
        productivity_score: calculate_activity_productivity_score(activity),
        output_per_fte: calculate_output_per_fte(activity),
        efficiency_ranking: calculate_activity_efficiency_ranking(activity)
      },
      utilization_metrics: {
        resource_utilization: calculate_activity_utilization_rate(activity),
        capacity_utilization: calculate_capacity_utilization(activity),
        workload_balance: calculate_workload_balance(activity)
      }
    }
  end
  
  def activity_benchmarking(activity)
    peer_activities = @period.activities.where(category: activity.category).where.not(id: activity.id)
    
    {
      peer_comparison: {
        avg_cost: peer_activities.average(:total_cost)&.round(2) || 0,
        activity_cost: activity.total_cost || 0,
        cost_percentile: calculate_cost_percentile(activity, peer_activities),
        efficiency_percentile: calculate_efficiency_percentile(activity, peer_activities)
      },
      industry_benchmarks: {
        best_practice_cost: calculate_best_practice_cost(activity),
        improvement_potential: calculate_improvement_potential(activity),
        benchmark_gap: calculate_benchmark_gap(activity)
      }
    }
  end
  
  def activity_summary
    activities = @period.activities
    total_cost = activities.sum(&:total_cost)
    
    {
      total_activities: activities.count,
      total_cost: total_cost,
      avg_cost_per_activity: total_cost / [activities.count, 1].max,
      cost_by_category: activities.group(:category).sum(&:total_cost),
      top_cost_activities: activities.order(:total_cost => :desc).limit(5).map do |activity|
        {
          name: activity.name,
          code: activity.code,
          cost: activity.total_cost,
          percentage: (activity.total_cost / total_cost * 100).round(2)
        }
      end,
      efficiency_overview: {
        high_efficiency: activities.select { |a| calculate_activity_productivity_score(a) > 75 }.count,
        medium_efficiency: activities.select { |a| calculate_activity_productivity_score(a).between?(50, 75) }.count,
        low_efficiency: activities.select { |a| calculate_activity_productivity_score(a) < 50 }.count
      }
    }
  end
  
  def activity_cost_analysis
    activities = @period.activities
    
    {
      cost_distribution: {
        allocated_cost: activities.sum(&:allocated_cost),
        employee_cost: activities.sum(&:employee_cost),
        total_cost: activities.sum(&:total_cost)
      },
      variance_analysis: {
        total_variance: activities.sum { |a| (a.total_cost || 0) - (a.allocated_cost || 0) },
        avg_variance: activities.average { |a| (a.total_cost || 0) - (a.allocated_cost || 0) }&.round(2) || 0
      }
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
  def calculate_activity_cost_percentage(activity)
    total_period_cost = @period.activities.sum(&:total_cost)
    return 0 if total_period_cost == 0
    
    ((activity.total_cost || 0) / total_period_cost * 100).round(2)
  end
  
  def calculate_cost_per_hour(activity)
    total_hours = activity.total_hours || 0
    return 0 if total_hours == 0
    
    (activity.total_cost || 0) / total_hours
  end
  
  def calculate_cost_per_fte(activity)
    total_fte = activity.total_fte || 0
    return 0 if total_fte == 0
    
    (activity.total_cost || 0) / total_fte
  end
  
  def calculate_activity_productivity_score(activity)
    # Simplified productivity calculation
    cost_per_hour = calculate_cost_per_hour(activity)
    utilization = calculate_activity_utilization_rate(activity)
    
    return 0 if cost_per_hour == 0
    (utilization / cost_per_hour * 100).round(2)
  end
  
  def calculate_activity_utilization_rate(activity)
    work_ratios = @period.work_ratios.where(activity: activity)
    return 0 if work_ratios.empty?
    
    (work_ratios.average(:ratio) * 100).round(2)
  end
  
  def calculate_allocation_completeness(activity)
    has_accounts = activity.has_account_mappings?
    has_processes = activity.has_process_mappings?
    has_employees = activity.has_employee_assignments?
    
    score = 0
    score += 33.33 if has_accounts
    score += 33.33 if has_processes  
    score += 33.34 if has_employees
    
    score.round(2)
  end
  
  # Placeholder methods for complex calculations
  def cost_by_category(activities)
    activities.group(:category).sum(&:total_cost)
  end
  
  def cost_by_department(activities)
    activities.joins(:department).group('departments.name').sum(&:total_cost)
  end
  
  def cost_by_type(activities)
    {
      allocated_cost: activities.sum(&:allocated_cost),
      employee_cost: activities.sum(&:employee_cost)
    }
  end
  
  def pareto_analysis(activities)
    { message: "Pareto analysis - implementation pending" }
  end
  
  def cost_concentration_analysis(activities)
    { message: "Cost concentration analysis - implementation pending" }
  end
  
  def unit_cost_analysis(activities)
    { message: "Unit cost analysis - implementation pending" }
  end
  
  # Additional placeholder methods...
  def productivity_metrics(activities)
    { message: "Productivity metrics - implementation pending" }
  end
  
  def resource_utilization_analysis(activities)
    { message: "Resource utilization analysis - implementation pending" }
  end
  
  def efficiency_benchmarking(activities)
    { message: "Efficiency benchmarking - implementation pending" }
  end
  
  def identify_efficiency_improvements(activities)
    { message: "Efficiency improvements - implementation pending" }
  end
  
  def top_performing_activities(activities)
    activities.order(:total_cost => :desc).limit(5).map { |a| { name: a.name, cost: a.total_cost } }
  end
  
  def underperforming_activities(activities)
    activities.order(:total_cost => :asc).limit(5).map { |a| { name: a.name, cost: a.total_cost } }
  end
  
  def calculate_performance_trends(activities)
    { message: "Performance trends - implementation pending" }
  end
  
  def performance_variance_analysis(activities)
    { message: "Performance variance analysis - implementation pending" }
  end
  
  def activity_kpi_dashboard(activities)
    { message: "KPI dashboard - implementation pending" }
  end
  
  # More placeholder methods for detailed calculations...
  def calculate_account_percentage(activity, amount)
    return 0 if activity.total_cost == 0
    (amount / activity.total_cost * 100).round(2)
  end
  
  def calculate_employee_percentage(activity, amount)
    return 0 if activity.total_cost == 0
    (amount / activity.total_cost * 100).round(2)
  end
  
  def calculate_cost_variance_percentage(activity)
    allocated = activity.allocated_cost || 0
    return 0 if allocated == 0
    
    variance = (activity.total_cost || 0) - allocated
    (variance / allocated * 100).round(2)
  end
  
  def calculate_resource_utilization_score(activity)
    75.0 # Placeholder
  end
  
  def calculate_process_allocated_cost(activity, mapping)
    return 0 unless mapping
    (activity.total_cost || 0) * (mapping.rate || 0)
  end
  
  def calculate_process_revenue_potential(process)
    process.total_revenue || 0
  end
  
  def calculate_output_per_fte(activity)
    100.0 # Placeholder
  end
  
  def calculate_activity_efficiency_ranking(activity)
    { rank: 1, total: 10, percentile: 90 } # Placeholder
  end
  
  def calculate_capacity_utilization(activity)
    80.0 # Placeholder
  end
  
  def calculate_workload_balance(activity)
    75.0 # Placeholder
  end
  
  def calculate_cost_percentile(activity, peer_activities)
    50.0 # Placeholder
  end
  
  def calculate_efficiency_percentile(activity, peer_activities)
    75.0 # Placeholder
  end
  
  def calculate_best_practice_cost(activity)
    (activity.total_cost || 0) * 0.8 # Placeholder - 20% improvement potential
  end
  
  def calculate_improvement_potential(activity)
    (activity.total_cost || 0) * 0.2 # Placeholder - 20% improvement potential
  end
  
  def calculate_benchmark_gap(activity)
    (activity.total_cost || 0) - calculate_best_practice_cost(activity)
  end
end