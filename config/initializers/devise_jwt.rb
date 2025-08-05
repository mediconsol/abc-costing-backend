# frozen_string_literal: true

Devise.setup do |config|
  config.jwt do |jwt|
    # 환경변수에서 JWT 시크릿 키 가져오기
    jwt_secret = ENV['DEVISE_JWT_SECRET_KEY'] || Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base
    
    jwt.secret = jwt_secret
    jwt.dispatch_requests = [
      ['POST', %r{^/api/v1/auth/login$}]
    ]
    jwt.revocation_requests = [
      ['DELETE', %r{^/api/v1/auth/logout$}]
    ]
    jwt.expiration_time = 1.day.to_i
  end
end