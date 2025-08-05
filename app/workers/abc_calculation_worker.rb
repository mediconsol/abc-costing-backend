class AbcCalculationWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: 'abc_calculations', retry: 2, backtrace: true
  
  def perform(hospital_id, period_id, user_id = nil)
    hospital = Hospital.find(hospital_id)
    period = hospital.periods.find(period_id)
    user = User.find(user_id) if user_id
    
    # Update status to in_progress
    period.update!(
      calculation_status: 'in_progress',
      calculation_started_at: Time.current
    )
    
    # Log job start
    Rails.logger.info "Starting ABC calculation for Hospital: #{hospital.name}, Period: #{period.name}"
    
    begin
      # Execute ABC calculation
      calculation_service = AbcCalculationService.new(hospital, period)
      
      if calculation_service.execute
        # Update status to completed
        period.update!(
          calculation_status: 'completed',
          last_calculated_at: Time.current,
          calculation_completed_at: Time.current,
          calculation_error: nil
        )
        
        # Log success
        Rails.logger.info "ABC calculation completed successfully for Hospital: #{hospital.name}, Period: #{period.name}"
        
        # Send notification if user provided
        if user
          AbcCalculationMailer.calculation_completed(user, hospital, period).deliver_now
        end
        
        # Trigger report generation if needed
        ReportGenerationWorker.perform_async(hospital_id, period_id, 'abc_summary')
        
      else
        # Handle calculation failure
        error_message = calculation_service.errors.join(', ')
        period.update!(
          calculation_status: 'failed',
          calculation_error: error_message,
          calculation_completed_at: Time.current
        )
        
        Rails.logger.error "ABC calculation failed for Hospital: #{hospital.name}, Period: #{period.name}. Errors: #{error_message}"
        
        # Send failure notification
        if user
          AbcCalculationMailer.calculation_failed(user, hospital, period, error_message).deliver_now
        end
        
        raise StandardError, "ABC calculation failed: #{error_message}"
      end
      
    rescue => e
      # Handle unexpected errors
      error_message = "Unexpected error: #{e.message}"
      period.update!(
        calculation_status: 'failed',
        calculation_error: error_message,
        calculation_completed_at: Time.current
      )
      
      Rails.logger.error "ABC calculation worker error: #{e.message}\\n#{e.backtrace.join("\\n")}"
      
      # Send error notification
      if user
        AbcCalculationMailer.calculation_failed(user, hospital, period, error_message).deliver_now
      end
      
      # Re-raise to mark job as failed
      raise e
    end
  end
  
  # Callback for successful job completion
  def self.on_success(job, elapsed_time)
    Rails.logger.info "ABC calculation job completed in #{elapsed_time.round(2)} seconds"
  end
  
  # Callback for job failure
  def self.on_failure(job, exception)
    hospital_id, period_id, user_id = job['args']
    Rails.logger.error "ABC calculation job failed for hospital_id: #{hospital_id}, period_id: #{period_id}. Error: #{exception.message}"
  end
end