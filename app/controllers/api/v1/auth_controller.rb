class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [:login, :signup]
  skip_before_action :ensure_json_request, only: [:login, :signup]
  
  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: login_params[:email])
    
    if user&.valid_password?(login_params[:password])
      token = encode_token(user_id: user.id)
      
      render_success({
        user: user_data(user),
        token: token,
        hospitals: user.accessible_hospitals.map { |h| hospital_data(h, user) }
      }, 'Successfully logged in')
    else
      render_error('Invalid email or password', :unauthorized)
    end
  end
  
  # DELETE /api/v1/auth/logout  
  def logout
    # JWT는 stateless이므로 클라이언트에서 토큰 제거
    # 필요시 denylist에 추가 가능
    render_success(nil, 'Successfully logged out')
  end
  
  # GET /api/v1/auth/me
  def me
    render_success({
      user: user_data(current_user),
      hospitals: current_user.accessible_hospitals.map { |h| hospital_data(h, current_user) }
    })
  end
  
  # POST /api/v1/auth/signup
  def signup
    user = User.new(signup_params)
    
    if user.save
      token = encode_token(user_id: user.id)
      
      render_success({
        user: user_data(user),
        token: token
      }, 'Account created successfully', :created)
    else
      render_error('Registration failed', :unprocessable_entity, user.errors)
    end
  end
  
  private
  
  def login_params
    params.require(:auth).permit(:email, :password)
  end
  
  def signup_params
    params.require(:auth).permit(:name, :email, :password, :password_confirmation)
  end
  
  def encode_token(payload)
    JWT.encode(payload, Rails.application.secret_key_base)
  end
  
  def user_data(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      created_at: user.created_at
    }
  end
  
  def hospital_data(hospital, user)
    {
      id: hospital.id,
      name: hospital.name,
      hospital_type: hospital.hospital_type,
      role: user.role_for_hospital(hospital),
      active_period: hospital.active_period&.then do |period|
        {
          id: period.id,
          name: period.name,
          start_date: period.start_date,
          end_date: period.end_date
        }
      end
    }
  end
end