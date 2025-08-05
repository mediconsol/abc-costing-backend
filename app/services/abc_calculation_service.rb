class AbcCalculationService
  attr_reader :hospital, :period, :errors
  
  def initialize(hospital, period)
    @hospital = hospital
    @period = period
    @errors = []
  end
  
  def execute
    return false unless validate_prerequisites
    
    begin
      ActiveRecord::Base.transaction do
        # Stage 1: Resource Cost Allocation (Account → Activity)
        stage1_result = ResourceCostAllocationService.new(hospital, period).execute
        raise "Stage 1 failed: #{stage1_result[:errors].join(', ')}" unless stage1_result[:success]
        
        # Stage 2: Activity Cost Pool Creation
        stage2_result = ActivityCostPoolService.new(hospital, period).execute
        raise "Stage 2 failed: #{stage2_result[:errors].join(', ')}" unless stage2_result[:success]
        
        # Stage 3: Process Cost Assignment (Activity → Process)
        stage3_result = ProcessCostAssignmentService.new(hospital, period).execute
        raise "Stage 3 failed: #{stage3_result[:errors].join(', ')}" unless stage3_result[:success]
        
        # Update period calculation status
        @period.update!(
          last_calculated_at: Time.current,
          calculation_status: 'completed'
        )
        
        true
      end
    rescue => e
      @errors << e.message
      @period.update(calculation_status: 'failed')
      false
    end
  end
  
  def calculation_summary
    {
      hospital_id: hospital.id,
      hospital_name: hospital.name,
      period_id: period.id,
      period_name: period.name,
      calculated_at: period.last_calculated_at,
      status: period.calculation_status,
      total_accounts: period.accounts.count,
      total_activities: period.activities.count,
      total_processes: period.processes.count,
      total_cost_allocated: period.accounts.sum(&:total_cost),
      mapped_accounts: period.account_activity_mappings.joins(:account).distinct.count('accounts.id'),
      mapped_activities: period.activity_process_mappings.joins(:activity).distinct.count('activities.id')
    }
  end
  
  private
  
  def validate_prerequisites
    # Check if accounts have cost inputs
    if period.accounts.joins(:cost_inputs).empty?
      @errors << "No cost inputs found for any accounts in period #{period.name}"
    end
    
    # Check if account-activity mappings exist
    if period.account_activity_mappings.empty?
      @errors << "No account-activity mappings found for period #{period.name}"
    end
    
    # Check if activity-process mappings exist
    if period.activity_process_mappings.empty?
      @errors << "No activity-process mappings found for period #{period.name}"
    end
    
    # Check if employees have work ratios
    if period.work_ratios.empty?
      @errors << "No employee work ratios found for period #{period.name}"
    end
    
    @errors.empty?
  end
end