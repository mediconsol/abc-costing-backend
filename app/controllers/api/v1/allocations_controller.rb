class Api::V1::AllocationsController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :require_manager!
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/allocations/execute
  def execute
    # Check if calculation is already in progress
    if @period.calculation_status == 'in_progress'
      render_error('Calculation already in progress for this period', :conflict)
      return
    end
    
    begin
      # Create job status record
      job_id = SecureRandom.uuid
      job_status = JobStatus.create!(
        job_id: job_id,
        job_type: 'abc_calculation',
        status: 'pending',
        total_steps: 3, # 3 stages of ABC calculation
        completed_steps: 0,
        hospital: current_hospital,
        period: @period,
        user: current_user,
        progress_message: 'ABC calculation queued for processing'
      )
      
      # Queue the background job
      AbcCalculationWorker.perform_async(
        current_hospital.id,
        @period.id,
        current_user.id
      )
      
      # Update period status
      @period.update!(
        calculation_status: 'pending',
        calculation_started_at: nil,
        calculation_completed_at: nil,
        calculation_error: nil
      )
      
      render_success({
        job_id: job_id,
        status: 'queued',
        message: 'ABC calculation has been queued for background processing',
        estimated_duration: estimate_calculation_time
      }, 'ABC calculation job queued successfully', :accepted)
      
    rescue => e
      Rails.logger.error "Failed to queue ABC calculation: #{e.message}"
      render_error("Failed to queue calculation: #{e.message}", :internal_server_error)
    end
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/allocations/status/:job_id
  def status
    job_id = params[:job_id]
    
    if job_id
      # Get specific job status
      job_status = JobStatus.find_by(job_id: job_id, hospital: current_hospital)
      
      unless job_status
        render_error('Job not found', :not_found)
        return
      end
      
      render_success({
        job_id: job_status.job_id,
        job_type: job_status.job_type,
        status: job_status.status,
        progress: {
          percentage: job_status.progress_percentage,
          completed_steps: job_status.completed_steps,
          total_steps: job_status.total_steps,
          message: job_status.progress_message
        },
        duration: job_status.duration,
        estimated_remaining_time: job_status.estimated_remaining_time,
        started_at: job_status.started_at,
        completed_at: job_status.completed_at,
        error_message: job_status.error_message,
        period: {
          id: @period.id,
          name: @period.name,
          calculation_status: @period.calculation_status
        }
      })
    else
      # Get period calculation status
      render_success({
        period_id: @period.id,
        period_name: @period.name,
        calculation_status: @period.calculation_status,
        last_calculated_at: @period.last_calculated_at,
        calculation_started_at: @period.calculation_started_at,
        calculation_completed_at: @period.calculation_completed_at,
        calculation_error: @period.calculation_error,
        progress: calculation_progress
      })
    end
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/allocations/results
  def results
    if @period.calculation_status != 'completed'
      render_error('Calculation not completed yet', :precondition_failed)
      return
    end
    
    render_success({
      calculation_summary: calculation_summary,
      allocation_results: allocation_results,
      cost_flows: cost_flows
    })
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def calculation_progress
    # Calculate progress based on completed stages
    total_stages = 3
    completed_stages = 0
    
    case @period.calculation_status
    when 'completed'
      completed_stages = 3
    when 'in_progress'
      # For now, assume partial progress
      completed_stages = 1
    when 'failed', 'pending'
      completed_stages = 0
    end
    
    {
      total_stages: total_stages,
      completed_stages: completed_stages,
      percentage: (completed_stages.to_f / total_stages * 100).round(2)
    }
  end
  
  def calculation_summary
    {
      period: {
        id: @period.id,
        name: @period.name,
        start_date: @period.start_date,
        end_date: @period.end_date
      },
      totals: {
        accounts_count: @period.accounts.count,
        activities_count: @period.activities.count,
        processes_count: @period.processes.count,
        employees_count: @period.employees.count,
        total_account_cost: @period.accounts.sum(&:total_cost),
        total_activity_cost: @period.activities.sum(&:total_cost),
        total_process_cost: @period.processes.sum(&:total_cost)
      },
      mappings: {
        account_activity_mappings: @period.account_activity_mappings.count,
        activity_process_mappings: @period.activity_process_mappings.count,
        work_ratios: @period.work_ratios.count
      },
      calculated_at: @period.last_calculated_at
    }
  end
  
  def allocation_results
    {
      accounts: account_allocation_results,
      activities: activity_allocation_results,
      processes: process_allocation_results
    }
  end
  
  def account_allocation_results
    @period.accounts.includes(:activities).map do |account|
      {
        id: account.id,
        code: account.code,
        name: account.name,
        category: account.category,
        is_direct: account.is_direct,
        total_cost: account.total_cost,
        allocated_to_activities: account.activities.map do |activity|
          mapping = account.account_activity_mappings.find_by(activity: activity)
          {
            activity_id: activity.id,
            activity_code: activity.code,
            activity_name: activity.name,
            ratio: mapping&.ratio || 0,
            allocated_amount: mapping&.allocated_amount || 0
          }
        end
      }
    end
  end
  
  def activity_allocation_results
    @period.activities.includes(:processes, :employees).map do |activity|
      {
        id: activity.id,
        code: activity.code,
        name: activity.name,
        category: activity.category,
        allocated_cost: activity.allocated_cost,
        employee_cost: activity.employee_cost,
        total_cost: activity.total_cost,
        total_fte: activity.total_fte,
        total_hours: activity.total_hours,
        unit_cost: activity.unit_cost,
        assigned_employees: activity.employees.count,
        mapped_processes: activity.processes.count
      }
    end
  end
  
  def process_allocation_results
    @period.processes.includes(:activity, :revenue_codes).map do |process|
      {
        id: process.id,
        code: process.code,
        name: process.name,
        category: process.category,
        is_billable: process.is_billable,
        allocated_cost: process.allocated_cost,
        total_cost: process.total_cost,
        unit_cost: process.unit_cost,
        total_volume: process.total_volume,
        total_revenue: process.total_revenue,
        profit_margin: process.profit_margin
      }
    end
  end
  
  def estimate_calculation_time
    # Estimate calculation time based on data size
    accounts_count = @period.accounts.count
    activities_count = @period.activities.count
    processes_count = @period.processes.count
    mappings_count = @period.account_activity_mappings.count + @period.activity_process_mappings.count
    
    # Base time (seconds) + time per entity
    base_time = 30
    time_per_account = 0.1
    time_per_activity = 0.2
    time_per_process = 0.1
    time_per_mapping = 0.05
    
    estimated_seconds = base_time + 
                       (accounts_count * time_per_account) +
                       (activities_count * time_per_activity) +
                       (processes_count * time_per_process) +
                       (mappings_count * time_per_mapping)
    
    {
      estimated_seconds: estimated_seconds.round,
      estimated_minutes: (estimated_seconds / 60.0).round(1),
      factors: {
        accounts: accounts_count,
        activities: activities_count,
        processes: processes_count,
        mappings: mappings_count
      }
    }
  end
  
  def cost_flows
    # Show how costs flow through the ABC system
    {
      stage1_account_to_activity: {
        description: "Resource costs allocated from accounts to activities",
        total_allocated: @period.activities.sum(:allocated_cost),
        mappings_count: @period.account_activity_mappings.count
      },
      stage2_employee_to_activity: {
        description: "Employee costs allocated to activities",
        total_allocated: @period.activities.sum(:employee_cost),
        work_ratios_count: @period.work_ratios.count
      },
      stage3_activity_to_process: {
        description: "Activity costs allocated to processes",
        total_allocated: @period.processes.sum(:allocated_cost),
        mappings_count: @period.activity_process_mappings.count
      }
    }
  end
end