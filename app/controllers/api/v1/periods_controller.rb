class Api::V1::PeriodsController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period, only: [:show, :update, :destroy, :activate]
  before_action :require_manager!, only: [:create, :update, :destroy, :activate]
  
  # GET /api/v1/hospitals/:hospital_id/periods
  def index
    @periods = current_hospital.periods.order(created_at: :desc)
    
    # 필터링
    @periods = @periods.where(is_active: true) if params[:active_only] == 'true'
    @periods = @periods.by_year(params[:year]) if params[:year].present?
    
    render_success({
      periods: @periods.map { |period| period_data(period) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:id
  def show
    render_success({
      period: period_data(@period, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods
  def create
    @period = current_hospital.periods.build(period_params)
    
    if @period.save
      render_success({
        period: period_data(@period)
      }, 'Period created successfully', :created)
    else
      render_error('Period creation failed', :unprocessable_entity, @period.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:id
  def update
    if @period.update(period_params)
      render_success({
        period: period_data(@period)
      }, 'Period updated successfully')
    else
      render_error('Period update failed', :unprocessable_entity, @period.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:id
  def destroy
    if @period.is_active?
      render_error('Cannot delete active period', :unprocessable_entity)
      return
    end
    
    @period.destroy
    render_success(nil, 'Period deleted successfully')
  end
  
  # PATCH /api/v1/hospitals/:hospital_id/periods/:id/activate
  def activate
    begin
      @period.activate!
      render_success({
        period: period_data(@period)
      }, 'Period activated successfully')
    rescue StandardError => e
      render_error("Failed to activate period: #{e.message}", :unprocessable_entity)
    end
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def period_params
    params.require(:period).permit(:name, :start_date, :end_date, :is_active)
  end
  
  def period_data(period, include_details: false)
    data = {
      id: period.id,
      name: period.name,
      start_date: period.start_date,
      end_date: period.end_date,
      is_active: period.is_active,
      display_name: period.display_name,
      duration_days: period.duration_days,
      hospital_id: period.hospital_id,
      created_at: period.created_at,
      updated_at: period.updated_at
    }
    
    if include_details
      data.merge!({
        departments_count: period.departments.count,
        accounts_count: period.accounts.count,
        activities_count: period.activities.count,
        employees_count: period.employees.count
      })
    end
    
    data
  end
end