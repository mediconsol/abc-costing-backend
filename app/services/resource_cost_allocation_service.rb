class ResourceCostAllocationService
  attr_reader :hospital, :period, :errors
  
  def initialize(hospital, period)
    @hospital = hospital
    @period = period
    @errors = []
  end
  
  def execute
    begin
      # Reset existing allocations
      reset_activity_costs
      
      # Allocate direct costs first
      allocate_direct_costs
      
      # Then allocate indirect costs using allocation ratios
      allocate_indirect_costs
      
      {
        success: true,
        message: "Resource cost allocation completed successfully",
        allocated_accounts: allocated_accounts_count,
        total_allocated: total_allocated_amount
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
  
  def reset_activity_costs
    # Clear previous allocations
    period.activities.update_all(allocated_cost: 0)
  end
  
  def allocate_direct_costs
    # Direct accounts are allocated 100% to their assigned activities
    direct_accounts = period.accounts.where(is_direct: true)
    
    direct_accounts.each do |account|
      # For direct accounts, typically 100% goes to one activity
      mappings = account.account_activity_mappings
      
      if mappings.any?
        mappings.each do |mapping|
          allocated_amount = account.total_cost * mapping.ratio
          
          # Add to activity's allocated cost
          mapping.activity.increment!(:allocated_cost, allocated_amount)
          
          # Log the allocation
          Rails.logger.info "Direct allocation: Account #{account.code} -> Activity #{mapping.activity.code}: #{allocated_amount}"
        end
      else
        @errors << "Direct account #{account.code} has no activity mappings"
      end
    end
  end
  
  def allocate_indirect_costs
    # Indirect accounts are allocated using predefined ratios or drivers
    indirect_accounts = period.accounts.where(is_direct: false)
    
    indirect_accounts.each do |account|
      mappings = account.account_activity_mappings
      
      if mappings.any?
        # Validate that ratios sum to 1.0 (100%)
        total_ratio = mappings.sum(:ratio)
        
        if (total_ratio - 1.0).abs > 0.001  # Allow small floating point differences
          @errors << "Account #{account.code} allocation ratios sum to #{total_ratio}, not 1.0"
          next
        end
        
        mappings.each do |mapping|
          allocated_amount = account.total_cost * mapping.ratio
          
          # Add to activity's allocated cost
          mapping.activity.increment!(:allocated_cost, allocated_amount)
          
          # Log the allocation
          Rails.logger.info "Indirect allocation: Account #{account.code} -> Activity #{mapping.activity.code}: #{allocated_amount} (#{(mapping.ratio * 100).round(2)}%)"
        end
      else
        # Unallocated indirect costs - these should be flagged for review
        Rails.logger.warn "Indirect account #{account.code} has no activity mappings - cost remains unallocated"
      end
    end
  end
  
  def allocated_accounts_count
    period.accounts.joins(:account_activity_mappings).distinct.count
  end
  
  def total_allocated_amount
    period.activities.sum(:allocated_cost)
  end
end