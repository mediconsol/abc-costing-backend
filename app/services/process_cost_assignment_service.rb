class ProcessCostAssignmentService
  attr_reader :hospital, :period, :errors
  
  def initialize(hospital, period)
    @hospital = hospital
    @period = period
    @errors = []
  end
  
  def execute
    begin
      # Reset existing process costs
      reset_process_costs
      
      # Allocate activity costs to processes using drivers
      allocate_activity_costs_to_processes
      
      # Calculate process unit costs and profitability
      calculate_process_metrics
      
      {
        success: true,
        message: "Process cost assignment completed successfully",
        processes_assigned: processes_with_costs_count,
        total_process_cost: total_process_cost
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
  
  def reset_process_costs
    # Clear previous process cost calculations
    period.processes.update_all(
      allocated_cost: 0,
      total_cost: 0,
      unit_cost: 0
    )
  end
  
  def allocate_activity_costs_to_processes
    # Process each activity-process mapping
    period.activity_process_mappings.includes(:activity, :process, :driver).each do |mapping|
      activity = mapping.activity
      process = mapping.process
      driver = mapping.driver
      
      if activity.total_cost <= 0
        Rails.logger.warn "Activity #{activity.code} has no cost to allocate"
        next
      end
      
      allocated_cost = calculate_allocated_cost(mapping)
      
      # Add allocated cost to process
      process.increment!(:allocated_cost, allocated_cost)
      process.increment!(:total_cost, allocated_cost)
      
      Rails.logger.info "Process allocation: Activity #{activity.code} -> Process #{process.code}: #{allocated_cost} via #{driver&.name || 'direct'}"
    end
  end
  
  def calculate_allocated_cost(mapping)
    activity = mapping.activity
    process = mapping.process
    driver = mapping.driver
    rate = mapping.rate
    
    if driver.nil?
      # Direct allocation using rate as percentage
      activity.total_cost * rate
    else
      # Driver-based allocation
      case driver.driver_type
      when 'volume'
        calculate_volume_based_allocation(mapping)
      when 'time'
        calculate_time_based_allocation(mapping)
      when 'resource'
        calculate_resource_based_allocation(mapping)
      else
        # Default to rate-based allocation
        activity.total_cost * rate
      end
    end
  end
  
  def calculate_volume_based_allocation(mapping)
    activity = mapping.activity
    process = mapping.process
    driver = mapping.driver
    
    # Get total volume for this driver across all processes using this activity
    total_driver_volume = period.activity_process_mappings
                               .where(activity: activity, driver: driver)
                               .sum { |m| get_process_volume(m.process, driver) }
    
    if total_driver_volume > 0
      process_volume = get_process_volume(process, driver)
      allocation_ratio = process_volume.to_f / total_driver_volume
      activity.total_cost * allocation_ratio
    else
      0
    end
  end
  
  def calculate_time_based_allocation(mapping)
    activity = mapping.activity
    process = mapping.process
    
    # Use work ratios to determine time allocation
    total_process_hours = period.work_ratios
                               .where(activity: activity, process: process)
                               .sum(:hours_per_period)
    
    total_activity_hours = period.work_ratios
                                .where(activity: activity)
                                .sum(:hours_per_period)
    
    if total_activity_hours > 0
      allocation_ratio = total_process_hours.to_f / total_activity_hours
      activity.total_cost * allocation_ratio
    else
      0
    end
  end
  
  def calculate_resource_based_allocation(mapping)
    # Resource-based allocation using predefined rates
    activity = mapping.activity
    rate = mapping.rate
    
    activity.total_cost * rate
  end
  
  def get_process_volume(process, driver)
    # Get volume data for process based on driver
    # This would typically come from revenue codes and volume data
    process.revenue_codes
           .joins('LEFT JOIN volume_data ON revenue_codes.id = volume_data.revenue_code_id')
           .where('volume_data.period_id = ?', period.id)
           .sum('COALESCE(volume_data.volume, 0)')
  end
  
  def calculate_process_metrics
    period.processes.each do |process|
      # Calculate unit cost per procedure/service
      total_volume = process.total_volume
      unit_cost = if total_volume > 0 && process.total_cost > 0
                   process.total_cost / total_volume
                 else
                   0
                 end
      
      # Calculate profitability if revenue data exists
      total_revenue = process.total_revenue
      profit_margin = if total_revenue > 0 && process.total_cost > 0
                       ((total_revenue - process.total_cost) / total_revenue) * 100
                     else
                       0
                     end
      
      # Update process metrics
      process.update!(
        unit_cost: unit_cost,
        profit_margin: profit_margin
      )
      
      Rails.logger.info "Process metrics - #{process.code}: Unit Cost: #{unit_cost}, Profit Margin: #{profit_margin}%"
    end
  end
  
  def processes_with_costs_count
    period.processes.where('total_cost > 0').count
  end
  
  def total_process_cost
    period.processes.sum(:total_cost)
  end
end