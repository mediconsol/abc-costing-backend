class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers
  
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # JWT 인증을 위한 메서드
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token
      begin
        decoded_token = JWT.decode(token, Rails.application.secret_key_base)[0]
        @current_user = User.find(decoded_token['user_id'])
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    else
      render json: { error: 'Token missing' }, status: :unauthorized
    end
  end
  
  def current_user
    @current_user
  end
  
  private
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end
end
