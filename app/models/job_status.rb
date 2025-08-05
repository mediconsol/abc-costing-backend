class JobStatus < ApplicationRecord
  include HospitalScoped
  
  belongs_to :hospital
  belongs_to :period, optional: true
  belongs_to :user, optional: true
  
  validates :job_id, presence: true, uniqueness: true
  validates :job_type, presence: true
  validates :status, inclusion: { in: %w[pending running completed failed cancelled] }
  
  # 스코프
  scope :by_type, ->(type) { where(job_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  
  # 상태 메서드
  def pending?
    status == 'pending'
  end
  
  def running?
    status == 'running'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def finished?
    completed? || failed? || cancelled?
  end
  
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end
  
  def progress_percentage
    return 0 unless total_steps && total_steps > 0
    return 100 if completed?
    return 0 if pending?
    
    ((completed_steps || 0).to_f / total_steps * 100).round(2)
  end
  
  def estimated_remaining_time
    return nil unless started_at && total_steps && completed_steps
    return 0 if completed?
    
    elapsed = Time.current - started_at
    return nil if completed_steps == 0
    
    avg_time_per_step = elapsed / completed_steps
    remaining_steps = total_steps - completed_steps
    remaining_steps * avg_time_per_step
  end
  
  def update_progress(completed_steps, message = nil)
    update!(
      completed_steps: completed_steps,
      progress_message: message,
      updated_at: Time.current
    )
  end
  
  def mark_started
    update!(
      status: 'running',
      started_at: Time.current
    )
  end
  
  def mark_completed(result = nil)
    update!(
      status: 'completed',
      completed_at: Time.current,
      result: result,
      completed_steps: total_steps
    )
  end
  
  def mark_failed(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error_message
    )
  end
  
  def mark_cancelled
    update!(
      status: 'cancelled',
      completed_at: Time.current
    )
  end
end