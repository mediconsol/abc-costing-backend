class Api::V1::BaseController < ApplicationController
  # JSON 응답만 허용
  before_action :ensure_json_request
  
  # 에러 핸들링
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique
  rescue_from ArgumentError, with: :argument_error
  
  protected
  
  # 성공 응답
  def render_success(data = nil, message = nil, status = :ok)
    response = { success: true }
    response[:data] = data if data
    response[:message] = message if message
    render json: response, status: status
  end
  
  # 에러 응답
  def render_error(message, status = :unprocessable_entity, errors = nil)
    response = { 
      success: false, 
      message: message 
    }
    response[:errors] = errors if errors
    render json: response, status: status
  end
  
  private
  
  def ensure_json_request
    return if request.content_type =~ /application\/json/ || request.get?
    render json: { error: 'Content-Type must be application/json' }, status: :unsupported_media_type
  end
  
  def record_not_found(exception)
    render_error("Record not found: #{exception.message}", :not_found)
  end
  
  def record_invalid(exception)
    render_error("Validation failed", :unprocessable_entity, exception.record.errors)
  end
  
  def parameter_missing(exception)
    render_error("Required parameter missing: #{exception.param}", :bad_request)
  end
  
  def record_not_unique(exception)
    render_error("Record already exists", :conflict)
  end
  
  def argument_error(exception)
    render_error("Invalid argument: #{exception.message}", :bad_request)
  end
  
  # 페이지네이션 헬퍼
  def paginate_collection(collection, page: params[:page], per_page: params[:per_page])
    page = (page || 1).to_i
    per_page = [(per_page || 25).to_i, 100].min  # 최대 100개로 제한
    
    offset = (page - 1) * per_page
    total = collection.count
    
    {
      data: collection.offset(offset).limit(per_page),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_pages: (total / per_page.to_f).ceil,
        total_count: total,
        has_next: (page * per_page) < total,
        has_prev: page > 1
      }
    }
  end
end