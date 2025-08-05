# frozen_string_literal: true

Devise.setup do |config|
  config.jwt do |jwt|
    # Ensure JWT secret key is at least 32 characters long
    jwt_secret = ENV['DEVISE_JWT_SECRET_KEY'] || Rails.application.secret_key_base
    jwt.secret = jwt_secret.length >= 32 ? jwt_secret : Rails.application.secret_key_base
    
    jwt.dispatch_requests = [
      ['POST', %r{^/api/v1/auth/login$}]
    ]
    jwt.revocation_requests = [
      ['DELETE', %r{^/api/v1/auth/logout$}]
    ]
    jwt.expiration_time = 1.day.to_i
  end
end