class Api::V1::RevenueCodesController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_revenue_code, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/revenue_codes
  def index
    @revenue_codes = @period.revenue_codes.includes(:process)
    
    # 필터링
    @revenue_codes = @revenue_codes.where(category: params[:category]) if params[:category].present?
    @revenue_codes = @revenue_codes.where(process_id: params[:process_id]) if params[:process_id].present?
    @revenue_codes = @revenue_codes.active if params[:active_only] == 'true'
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @revenue_codes = @revenue_codes.where('code ILIKE ? OR name ILIKE ?', search_term, search_term)
    end
    
    # 정렬
    @revenue_codes = @revenue_codes.order(:code)
    
    render_success({
      revenue_codes: @revenue_codes.map { |revenue_code| revenue_code_data(revenue_code) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/revenue_codes/:id
  def show
    render_success({
      revenue_code: revenue_code_data(@revenue_code, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/revenue_codes
  def create
    @revenue_code = @period.revenue_codes.build(revenue_code_params)
    @revenue_code.hospital = current_hospital
    
    if @revenue_code.save
      render_success({
        revenue_code: revenue_code_data(@revenue_code)
      }, 'Revenue code created successfully', :created)
    else
      render_error('Revenue code creation failed', :unprocessable_entity, @revenue_code.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/revenue_codes/:id
  def update
    if @revenue_code.update(revenue_code_params)
      render_success({
        revenue_code: revenue_code_data(@revenue_code)
      }, 'Revenue code updated successfully')
    else
      render_error('Revenue code update failed', :unprocessable_entity, @revenue_code.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/revenue_codes/:id
  def destroy
    if @revenue_code.volume_data.any?
      render_error('Cannot delete revenue code with volume data', :unprocessable_entity)
      return
    end
    
    @revenue_code.destroy
    render_success(nil, 'Revenue code deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_revenue_code
    @revenue_code = @period.revenue_codes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Revenue code not found', :not_found)
  end
  
  def revenue_code_params
    params.require(:revenue_code).permit(:code, :name, :category, :process_id, :price, :is_active, :description)
  end
  
  def revenue_code_data(revenue_code, include_details: false)
    data = {
      id: revenue_code.id,
      code: revenue_code.code,
      name: revenue_code.name,
      category: revenue_code.category,
      price: revenue_code.price,
      is_active: revenue_code.is_active,
      description: revenue_code.description,
      process_id: revenue_code.process_id,
      display_name: revenue_code.display_name,
      full_name: revenue_code.full_name,
      process_name: revenue_code.process_name,
      hospital_id: revenue_code.hospital_id,
      period_id: revenue_code.period_id,
      created_at: revenue_code.created_at,
      updated_at: revenue_code.updated_at
    }
    
    if include_details
      data.merge!({
        total_volume: revenue_code.total_volume,
        total_revenue: revenue_code.total_revenue,
        monthly_volumes: revenue_code.monthly_volumes,
        monthly_revenues: revenue_code.monthly_revenues,
        average_monthly_volume: revenue_code.average_monthly_volume,
        average_monthly_revenue: revenue_code.average_monthly_revenue,
        process: revenue_code.process ? {
          id: revenue_code.process.id,
          code: revenue_code.process.code,
          name: revenue_code.process.name,
          category: revenue_code.process.category
        } : nil
      })
    end
    
    data
  end
end