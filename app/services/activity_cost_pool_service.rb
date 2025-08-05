class ActivityCostPoolService
  attr_reader :hospital, :period, :errors
  
  def initialize(hospital, period)
    @hospital = hospital
    @period = period
    @errors = []
  end
  
  def execute
    begin
      # Calculate employee costs allocated to activities
      calculate_employee_activity_costs
      
      # Calculate total activity costs (account allocations + employee costs)
      calculate_total_activity_costs
      
      # Calculate activity rates and efficiency metrics
      calculate_activity_metrics
      
      {
        success: true,
        message: "Activity cost pool creation completed successfully",
        activities_processed: activities_with_costs_count,
        total_activity_cost: total_activity_cost
      }
    rescue => e
      @errors << e.message
      {
        success: false,
        errors: @errors
      }
    end
  end
  
  private
  
  def calculate_employee_activity_costs
    # Calculate costs for each activity based on employee work ratios
    period.activities.each do |activity|
      employee_cost = 0
      
      # Sum up costs from all employees assigned to this activity
      work_ratios = period.work_ratios.where(activity: activity)
      
      work_ratios.each do |work_ratio|
        employee = work_ratio.employee
        allocated_hours = work_ratio.allocated_hours
        hourly_cost = employee.hourly_rate || (employee.annual_salary / 2080) # 2080 = 40 hours * 52 weeks
        
        employee_allocated_cost = allocated_hours * hourly_cost
        employee_cost += employee_allocated_cost
        
        Rails.logger.info "Employee allocation: #{employee.name} -> Activity #{activity.code}: #{employee_allocated_cost} (#{allocated_hours} hours @ #{hourly_cost}/hour)"
      end
      
      # Update activity with employee cost component
      activity.update!(
        employee_cost: employee_cost,
        total_cost: activity.allocated_cost + employee_cost
      )
    end
  end
  
  def calculate_total_activity_costs
    # Ensure total_cost is properly calculated for all activities
    period.activities.each do |activity|
      total_cost = (activity.allocated_cost || 0) + (activity.employee_cost || 0)
      activity.update!(total_cost: total_cost)
    end
  end
  
  def calculate_activity_metrics
    period.activities.each do |activity|
      # Calculate total FTE (Full-Time Equivalent) assigned to activity
      total_fte = period.work_ratios.where(activity: activity)
                       .joins(:employee)
                       .sum('work_ratios.ratio * employees.fte')
      
      # Calculate total hours assigned to activity
      total_hours = period.work_ratios.where(activity: activity)
                         .sum(:hours_per_period)
      
      # Calculate average hourly rate for activity
      avg_hourly_rate = if total_hours > 0 && activity.employee_cost > 0
                         activity.employee_cost / total_hours
                       else
                         0
                       end
      
      # Calculate unit cost (if we have volume data)
      unit_cost = calculate_unit_cost(activity)
      
      # Update activity metrics
      activity.update!(
        total_fte: total_fte,
        total_hours: total_hours,
        average_hourly_rate: avg_hourly_rate,
        unit_cost: unit_cost
      )
      
      Rails.logger.info "Activity metrics - #{activity.code}: Total Cost: #{activity.total_cost}, FTE: #{total_fte}, Hours: #{total_hours}, Unit Cost: #{unit_cost}"
    end
  end
  
  def calculate_unit_cost(activity)
    # Calculate cost per unit of activity output
    # This could be based on various drivers (patients treated, procedures performed, etc.)
    
    # For now, use a simple calculation based on process mappings
    total_volume = activity.activity_process_mappings
                          .joins(:process => :revenue_codes)
                          .joins('LEFT JOIN volume_data ON revenue_codes.id = volume_data.revenue_code_id')
                          .sum('COALESCE(volume_data.volume, 0)')
    
    if total_volume > 0 && activity.total_cost > 0
      activity.total_cost / total_volume
    else
      0
    end
  end
  
  def activities_with_costs_count
    period.activities.where('total_cost > 0').count
  end
  
  def total_activity_cost
    period.activities.sum(:total_cost)
  end
end