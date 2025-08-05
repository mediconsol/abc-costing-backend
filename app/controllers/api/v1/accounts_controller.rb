class Api::V1::AccountsController < Api::V1::BaseController
  include HospitalContext
  
  before_action :set_period
  before_action :set_account, only: [:show, :update, :destroy]
  before_action :require_manager!, only: [:create, :update, :destroy]
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/accounts
  def index
    @accounts = @period.accounts.includes(:activities)
    
    # 필터링
    @accounts = @accounts.where(category: params[:category]) if params[:category].present?
    @accounts = @accounts.where(is_direct: params[:is_direct]) if params[:is_direct].present?
    @accounts = @accounts.mapped_to_activities if params[:mapped_only] == 'true'
    @accounts = @accounts.unmapped if params[:unmapped_only] == 'true'
    
    # 검색
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @accounts = @accounts.where('code ILIKE ? OR name ILIKE ?', search_term, search_term)
    end
    
    # 정렬
    @accounts = @accounts.order(:code)
    
    render_success({
      accounts: @accounts.map { |account| account_data(account) }
    })
  end
  
  # GET /api/v1/hospitals/:hospital_id/periods/:period_id/accounts/:id
  def show
    render_success({
      account: account_data(@account, include_details: true)
    })
  end
  
  # POST /api/v1/hospitals/:hospital_id/periods/:period_id/accounts
  def create
    @account = @period.accounts.build(account_params)
    @account.hospital = current_hospital
    
    if @account.save
      render_success({
        account: account_data(@account)
      }, 'Account created successfully', :created)
    else
      render_error('Account creation failed', :unprocessable_entity, @account.errors)
    end
  end
  
  # PUT /api/v1/hospitals/:hospital_id/periods/:period_id/accounts/:id
  def update
    if @account.update(account_params)
      render_success({
        account: account_data(@account)
      }, 'Account updated successfully')
    else
      render_error('Account update failed', :unprocessable_entity, @account.errors)
    end
  end
  
  # DELETE /api/v1/hospitals/:hospital_id/periods/:period_id/accounts/:id
  def destroy
    if @account.cost_inputs.any?
      render_error('Cannot delete account with cost inputs', :unprocessable_entity)
      return
    end
    
    if @account.account_activity_mappings.any?
      render_error('Cannot delete account with activity mappings', :unprocessable_entity)
      return
    end
    
    @account.destroy
    render_success(nil, 'Account deleted successfully')
  end
  
  private
  
  def set_period
    @period = current_hospital.periods.find(params[:period_id])
  rescue ActiveRecord::RecordNotFound
    render_error('Period not found', :not_found)
  end
  
  def set_account
    @account = @period.accounts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Account not found', :not_found)
  end
  
  def account_params
    params.require(:account).permit(:code, :name, :category, :is_direct, :description)
  end
  
  def account_data(account, include_details: false)
    data = {
      id: account.id,
      code: account.code,
      name: account.name,
      category: account.category,
      is_direct: account.is_direct,
      description: account.description,
      display_name: account.display_name,
      category_humanized: account.category_humanized,
      mapped_activities_count: account.mapped_activities_count,
      has_mappings: account.has_mappings?,
      hospital_id: account.hospital_id,
      period_id: account.period_id,
      created_at: account.created_at,
      updated_at: account.updated_at
    }
    
    if include_details
      data.merge!({
        total_cost: account.total_cost,
        monthly_costs: account.monthly_costs,
        average_monthly_cost: account.average_monthly_cost,
        mapped_activities: account.activities.map do |activity|
          {
            id: activity.id,
            code: activity.code,
            name: activity.name,
            category: activity.category
          }
        end
      })
    end
    
    data
  end
end