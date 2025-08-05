# frozen_string_literal: true

Devise.setup do |config|
  config.jwt do |jwt|
    # Devise JWT는 16바이트 키를 요구하므로 SECRET_KEY_BASE의 첫 16바이트 사용
    # Railway 배포를 위한 수정 - 2025-08-05
    jwt.secret = Rails.application.secret_key_base[0, 16]
    
    jwt.dispatch_requests = [
      ['POST', %r{^/api/v1/auth/login$}]
    ]
    jwt.revocation_requests = [
      ['DELETE', %r{^/api/v1/auth/logout$}]
    ]
    jwt.expiration_time = 1.day.to_i
  end
end