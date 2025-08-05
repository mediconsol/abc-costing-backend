class Api::V1::Reports::ExportController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :require_manager!
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/reports/export
  def create
    unless @period.calculation_status == 'completed'
      render_error('ABC calculation must be completed before exporting reports', :precondition_failed)
      return
    end
    
    export_type = params[:export_type] || 'comprehensive'
    format = params[:format] || 'excel'
    include_charts = params[:include_charts] == 'true'
    
    begin
      # Create job for background processing
      job_id = SecureRandom.uuid
      job_status = JobStatus.create!(
        job_id: job_id,
        job_type: 'report_export',
        status: 'pending',
        total_steps: calculate_export_steps(export_type),
        completed_steps: 0,
        hospital: current_hospital,
        period: @period,
        user: current_user,
        progress_message: 'Export job queued for processing'
      )
      
      # Queue background job
      ReportExportWorker.perform_async(
        current_hospital.id,
        @period.id,
        current_user.id,
        job_id,
        export_type,
        format,
        include_charts
      )
      
      render_success({
        job_id: job_id,
        status: 'queued',
        export_type: export_type,
        format: format,
        estimated_duration: estimate_export_time(export_type)
      }, 'Export job queued successfully', :accepted)
      
    rescue => e
      Rails.logger.error "Failed to queue export job: #{e.message}"
      render_error("Failed to queue export: #{e.message}", :internal_server_error)
    end
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/export/templates
  def templates
    templates = {
      comprehensive: {
        name: 'Comprehensive ABC Report',
        description: 'Complete ABC analysis including all departments, activities, and processes',
        includes: ['summary', 'departments', 'activities', 'processes', 'kpis', 'cost_flows'],
        estimated_size: 'Large (10-20 MB)',
        estimated_time: '5-10 minutes'
      },
      executive: {
        name: 'Executive Summary',
        description: 'High-level summary for executive review',
        includes: ['summary', 'kpis', 'key_metrics', 'alerts'],
        estimated_size: 'Small (1-3 MB)',
        estimated_time: '1-2 minutes'
      },
      departmental: {
        name: 'Department Analysis',
        description: 'Detailed analysis by department',
        includes: ['departments', 'department_activities', 'cost_breakdown'],
        estimated_size: 'Medium (5-10 MB)',
        estimated_time: '3-5 minutes'
      },
      financial: {
        name: 'Financial Analysis',
        description: 'Focus on cost allocation and financial metrics',
        includes: ['cost_flows', 'budget_variance', 'financial_kpis'],
        estimated_size: 'Medium (3-7 MB)',
        estimated_time: '2-4 minutes'
      },
      operational: {
        name: 'Operational Metrics',
        description: 'Operational efficiency and productivity analysis',
        includes: ['activities', 'processes', 'efficiency_metrics', 'utilization'],
        estimated_size: 'Medium (4-8 MB)',
        estimated_time: '3-5 minutes'
      }
    }
    
    render_success({
      templates: templates,
      supported_formats: ['excel', 'csv', 'pdf'],
      period_info: {
        id: @period.id,
        name: @period.name,
        calculation_status: @period.calculation_status,
        last_calculated_at: @period.last_calculated_at
      }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/export/:job_id/download
  def download
    job_status = JobStatus.find_by!(job_id: params[:job_id], hospital: current_hospital)
    
    unless job_status.completed?
      render_error('Export is not yet completed', :precondition_failed)
      return
    end
    
    # In a real implementation, this would serve the actual file
    # For now, we'll return download information
    download_info = {
      job_id: job_status.job_id,
      status: job_status.status,
      download_url: generate_download_url(job_status),
      file_info: {
        filename: generate_filename(job_status),
        size: estimate_file_size(job_status),
        format: extract_format_from_result(job_status),
        created_at: job_status.completed_at
      },
      expires_at: job_status.completed_at + 7.days # Files expire after 7 days
    }
    
    render_success(download_info)
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/export/history
  def history
    exports = current_hospital.job_statuses
                             .where(job_type: 'report_export')
                             .where(period: @period)
                             .order(created_at: :desc)
                             .limit(50)
    
    export_history = exports.map do |export|
      {
        job_id: export.job_id,
        status: export.status,
        export_type: extract_export_type_from_result(export),
        format: extract_format_from_result(export),
        created_at: export.created_at,
        completed_at: export.completed_at,
        file_size: estimate_file_size(export),
        user: export.user ? {
          id: export.user.id,
          email: export.user.email
        } : nil,
        download_available: export.completed? && (export.completed_at + 7.days > Time.current)
      }
    end
    
    render_success({
      exports: export_history,
      summary: {
        total_exports: exports.count,
        completed_exports: exports.completed.count,
        failed_exports: exports.failed.count,
        pending_exports: exports.where(status: ['pending', 'running']).count
      }
    })
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/reports/export/:job_id
  def destroy
    job_status = JobStatus.find_by!(job_id: params[:job_id], hospital: current_hospital)
    
    # Can only delete completed or failed exports
    unless job_status.finished?
      render_error('Cannot delete running export job', :unprocessable_entity)
      return
    end
    
    # Delete the actual file (in real implementation)
    # delete_export_file(job_status)
    
    # Delete the job status record
    job_status.destroy
    
    render_success(nil, 'Export deleted successfully')
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/export/quick/:type
  def quick_export
    export_type = params[:type]
    
    unless %w[summary departments activities processes kpis].include?(export_type)
      render_error('Invalid export type', :bad_request)
      return
    end
    
    begin
      # Generate quick export data
      export_data = case export_type
                   when 'summary'
                     generate_summary_export
                   when 'departments'
                     generate_departments_export
                   when 'activities'
                     generate_activities_export
                   when 'processes'
                     generate_processes_export
                   when 'kpis'
                     generate_kpis_export
                   end
      
      render_success({
        export_type: export_type,
        data: export_data,
        generated_at: Time.current,
        period: {
          id: @period.id,
          name: @period.name
        }
      })
      
    rescue => e
      Rails.logger.error "Quick export failed: #{e.message}"
      render_error("Quick export failed: #{e.message}", :internal_server_error)
    end
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def calculate_export_steps(export_type)
    case export_type
    when 'comprehensive'
      10  # Many data sections to process
    when 'executive'
      3   # Summary data only
    when 'departmental'
      5   # Department-focused data
    when 'financial'
      4   # Financial data
    when 'operational'
      6   # Operational data
    else
      5   # Default
    end
  end
  
  def estimate_export_time(export_type)
    base_time = 60 # 1 minute base
    
    complexity_multiplier = case export_type
                           when 'comprehensive'
                             8
                           when 'executive'
                             2
                           when 'departmental'
                             4
                           when 'financial'
                             3
                           when 'operational'
                             5
                           else
                             4
                           end
    
    data_size_factor = calculate_data_size_factor
    
    estimated_seconds = base_time * complexity_multiplier * data_size_factor
    
    {
      estimated_seconds: estimated_seconds.round,
      estimated_minutes: (estimated_seconds / 60.0).round(1),
      factors: {
        base_time: base_time,
        complexity: complexity_multiplier,
        data_size: data_size_factor
      }
    }
  end
  
  def calculate_data_size_factor
    # Calculate factor based on amount of data to export
    accounts_count = @period.accounts.count
    activities_count = @period.activities.count
    processes_count = @period.processes.count
    departments_count = @period.departments.count
    
    total_entities = accounts_count + activities_count + processes_count + departments_count
    
    case total_entities
    when 0..100
      1.0
    when 101..500
      1.5
    when 501..1000
      2.0
    when 1001..2000
      2.5
    else
      3.0
    end
  end
  
  def generate_download_url(job_status)
    # In real implementation, this would be a signed URL to the actual file
    "/api/v1/hospitals/#{current_hospital.id}/periods/#{@period.id}/reports/export/#{job_status.job_id}/file"
  end
  
  def generate_filename(job_status)
    export_type = extract_export_type_from_result(job_status) || 'report'
    format = extract_format_from_result(job_status) || 'xlsx'
    timestamp = job_status.completed_at.strftime('%Y%m%d_%H%M%S')
    
    "#{current_hospital.name.downcase.gsub(/\\s+/, '_')}_#{export_type}_#{@period.name.downcase.gsub(/\\s+/, '_')}_#{timestamp}.#{format}"
  end
  
  def estimate_file_size(job_status)
    # Estimate file size based on export type and data volume
    export_type = extract_export_type_from_result(job_status)
    
    base_size = case export_type
               when 'comprehensive'
                 15_000_000  # 15 MB
               when 'executive'
                 2_000_000   # 2 MB
               when 'departmental'
                 8_000_000   # 8 MB
               when 'financial'
                 5_000_000   # 5 MB
               when 'operational'
                 6_000_000   # 6 MB
               else
                 4_000_000   # 4 MB default
               end
    
    # Adjust based on actual data size
    (base_size * calculate_data_size_factor).round
  end
  
  def extract_format_from_result(job_status)
    # Extract format from job result or default to excel
    result = job_status.result
    return 'xlsx' unless result
    
    begin
      parsed_result = JSON.parse(result)
      parsed_result['format'] || 'xlsx'
    rescue
      'xlsx'
    end
  end
  
  def extract_export_type_from_result(job_status)
    # Extract export type from job result or default
    result = job_status.result
    return 'comprehensive' unless result
    
    begin
      parsed_result = JSON.parse(result)
      parsed_result['export_type'] || 'comprehensive'
    rescue
      'comprehensive'
    end
  end
  
  # Quick export data generators
  def generate_summary_export
    {
      period_info: {
        name: @period.name,
        start_date: @period.start_date,
        end_date: @period.end_date,
        calculation_status: @period.calculation_status,
        last_calculated_at: @period.last_calculated_at
      },
      totals: {
        departments: @period.departments.count,
        activities: @period.activities.count,
        processes: @period.processes.count,
        employees: @period.employees.count,
        total_cost: @period.activities.sum(&:total_cost),
        total_revenue: @period.processes.billable.sum(&:total_revenue)
      },
      top_cost_centers: @period.departments.joins(:activities)
                               .group('departments.name')
                               .sum('activities.total_cost')
                               .sort_by { |_, cost| -cost }
                               .first(5)
                               .map { |name, cost| { name: name, cost: cost } }
    }
  end
  
  def generate_departments_export
    @period.departments.includes(:activities, :employees).map do |dept|
      {
        code: dept.code,
        name: dept.name,
        type: dept.department_type,
        manager: dept.manager,
        activities_count: dept.activities.count,
        employees_count: dept.employees.count,
        total_cost: dept.activities.sum(&:total_cost),
        total_fte: dept.employees.sum(&:fte)
      }
    end
  end
  
  def generate_activities_export
    @period.activities.includes(:department, :accounts, :processes).map do |activity|
      {
        code: activity.code,
        name: activity.name,
        category: activity.category,
        department: activity.department&.name,
        total_cost: activity.total_cost,
        allocated_cost: activity.allocated_cost,
        employee_cost: activity.employee_cost,
        unit_cost: activity.unit_cost,
        total_fte: activity.total_fte,
        total_hours: activity.total_hours,
        mapped_accounts: activity.accounts.count,
        mapped_processes: activity.processes.count
      }
    end
  end
  
  def generate_processes_export
    @period.processes.includes(:activity, :revenue_codes).map do |process|
      {
        code: process.code,
        name: process.name,
        category: process.category,
        is_billable: process.is_billable,
        activity: process.activity&.name,
        total_cost: process.total_cost,
        allocated_cost: process.allocated_cost,
        unit_cost: process.unit_cost,
        total_volume: process.total_volume,
        total_revenue: process.total_revenue,
        profit_margin: process.profit_margin,
        revenue_codes_count: process.revenue_codes.count
      }
    end
  end
  
  def generate_kpis_export
    total_cost = @period.activities.sum(&:total_cost)
    total_revenue = @period.processes.billable.sum(&:total_revenue)
    
    {
      financial_kpis: {
        total_cost: total_cost,
        total_revenue: total_revenue,
        profit_margin: total_revenue > 0 ? ((total_revenue - total_cost) / total_revenue * 100).round(2) : 0,
        roi: total_cost > 0 ? ((total_revenue - total_cost) / total_cost * 100).round(2) : 0,
        cost_per_patient: calculate_cost_per_patient_quick
      },
      operational_kpis: {
        resource_utilization: calculate_overall_utilization_quick,
        employee_productivity: calculate_employee_productivity_quick,
        process_efficiency: calculate_process_efficiency_quick,
        capacity_utilization: calculate_capacity_utilization_quick
      },
      activity_metrics: {
        activities_count: @period.activities.count,
        avg_activity_cost: @period.activities.average(:total_cost)&.round(2) || 0,
        top_cost_activity: @period.activities.order(:total_cost => :desc).first&.name
      }
    }
  end
  
  # Quick calculation helpers
  def calculate_cost_per_patient_quick
    total_cost = @period.activities.sum(&:total_cost)
    patient_count = 1000 # Placeholder
    return 0 if patient_count == 0
    
    (total_cost / patient_count).round(2)
  end
  
  def calculate_overall_utilization_quick
    work_ratios = @period.work_ratios
    return 0 if work_ratios.empty?
    
    (work_ratios.average(:ratio) * 100).round(2)
  end
  
  def calculate_employee_productivity_quick
    # Simplified productivity score
    85.3 # Placeholder
  end
  
  def calculate_process_efficiency_quick
    # Percentage of efficient processes
    92.1 # Placeholder
  end
  
  def calculate_capacity_utilization_quick
    # Current capacity utilization
    78.5 # Placeholder
  end
end