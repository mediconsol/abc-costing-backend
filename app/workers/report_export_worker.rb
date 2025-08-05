class ReportExportWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: 'reports', retry: 1, backtrace: true
  
  def perform(hospital_id, period_id, user_id, job_id, export_type, format, include_charts)
    hospital = Hospital.find(hospital_id)
    period = hospital.periods.find(period_id)
    user = User.find(user_id)
    job_status = JobStatus.find_by!(job_id: job_id)
    
    Rails.logger.info "Starting report export: #{export_type} (#{format}) for Hospital: #{hospital.name}, Period: #{period.name}"
    
    begin
      # Mark job as started
      job_status.mark_started
      
      # Generate export based on type
      export_service = ReportExportService.new(hospital, period, user)
      
      case export_type
      when 'comprehensive'
        result = export_service.generate_comprehensive_report(format, include_charts, job_status)
      when 'executive'
        result = export_service.generate_executive_report(format, include_charts, job_status)
      when 'departmental'
        result = export_service.generate_departmental_report(format, include_charts, job_status)
      when 'financial'
        result = export_service.generate_financial_report(format, include_charts, job_status)
      when 'operational'
        result = export_service.generate_operational_report(format, include_charts, job_status)
      else
        raise ArgumentError, "Unknown export type: #{export_type}"
      end
      
      # Mark job as completed
      job_status.mark_completed(result.to_json)
      
      Rails.logger.info "Report export completed: #{export_type} for Hospital: #{hospital.name}, Period: #{period.name}"
      
      # Send notification email
      ReportExportMailer.export_completed(user, hospital, period, export_type, job_id).deliver_now
      
    rescue => e
      error_message = "Export failed: #{e.message}"
      job_status.mark_failed(error_message)
      
      Rails.logger.error "Report export failed: #{e.message}\\n#{e.backtrace.join("\\n")}"
      
      # Send failure notification
      ReportExportMailer.export_failed(user, hospital, period, export_type, error_message).deliver_now
      
      raise e
    end
  end
end