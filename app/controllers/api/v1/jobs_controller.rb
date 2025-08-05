class Api::V1::JobsController < Api::V1::BaseController
  include HospitalContext
  
  # GET /api/v1/hospitals/:hospital_id/jobs
  def index
    @jobs = current_hospital.job_statuses.includes(:period, :user)
    
    # 필터링
    @jobs = @jobs.by_type(params[:type]) if params[:type].present?
    @jobs = @jobs.by_status(params[:status]) if params[:status].present?
    @jobs = @jobs.for_user(current_user) if params[:my_jobs] == 'true'
    
    # 페이지네이션
    paginated = paginate_collection(@jobs.recent)
    
    render_success({
      jobs: paginated[:data].map { |job| job_data(job) },
      pagination: paginated[:pagination]
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/jobs/:job_id
  def show
    @job = current_hospital.job_statuses.find_by!(job_id: params[:job_id])
    
    render_success({
      job: job_data(@job, include_details: true)
    })
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/jobs/:job_id
  def cancel
    @job = current_hospital.job_statuses.find_by!(job_id: params[:job_id])
    
    unless @job.pending? || @job.running?
      render_error('Job cannot be cancelled - it is already finished', :unprocessable_entity)
      return
    end
    
    begin
      # Cancel the Sidekiq job
      if @job.pending?
        # Find and delete from Sidekiq queue
        Sidekiq::Queue.new('abc_calculations').each do |job|
          if job.args.include?(@job.hospital.id) && job.args.include?(@job.period&.id)
            job.delete
            break
          end
        end
      end
      
      # Mark as cancelled
      @job.mark_cancelled
      
      # Update period status if it's an ABC calculation
      if @job.job_type == 'abc_calculation' && @job.period
        @job.period.update!(calculation_status: 'cancelled')
      end
      
      render_success({
        job: job_data(@job)
      }, 'Job cancelled successfully')
      
    rescue => e
      render_error("Failed to cancel job: #{e.message}", :internal_server_error)
    end
  end
  
  # GET /api/v1/hospitals/:hospital_id/jobs/summary
  def summary
    jobs = current_hospital.job_statuses
    
    summary = {
      total_jobs: jobs.count,
      by_status: {
        pending: jobs.by_status('pending').count,
        running: jobs.by_status('running').count,
        completed: jobs.by_status('completed').count,
        failed: jobs.by_status('failed').count,
        cancelled: jobs.by_status('cancelled').count
      },
      by_type: {},
      recent_activity: jobs.recent.limit(10).map { |job| job_data(job) }
    }
    
    # Count by job types
    jobs.group(:job_type).count.each do |type, count|
      summary[:by_type][type] = count
    end
    
    render_success(summary)
  end
  
  private
  
  def job_data(job, include_details: false)
    data = {
      job_id: job.job_id,
      job_type: job.job_type,
      status: job.status,
      progress: {
        percentage: job.progress_percentage,
        completed_steps: job.completed_steps,
        total_steps: job.total_steps,
        message: job.progress_message
      },
      created_at: job.created_at,
      started_at: job.started_at,
      completed_at: job.completed_at,
      duration: job.duration,
      period: job.period ? {
        id: job.period.id,
        name: job.period.name
      } : nil,
      user: job.user ? {
        id: job.user.id,
        email: job.user.email
      } : nil
    }
    
    if include_details
      data.merge!({
        error_message: job.error_message,
        result: job.result,
        estimated_remaining_time: job.estimated_remaining_time,
        hospital: {
          id: job.hospital.id,
          name: job.hospital.name
        }
      })
    end
    
    data
  end
end