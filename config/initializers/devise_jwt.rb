# frozen_string_literal: true

# Devise JWT 설정 - Railway 배포를 위해 임시 비활성화
# TODO: JWT 설정을 나중에 활성화

# Devise.setup do |config|
#   config.jwt do |jwt|
#     jwt.secret = Rails.application.secret_key_base[0, 16]
#     jwt.dispatch_requests = [
#       ['POST', %r{^/api/v1/auth/login$}]
#     ]
#     jwt.revocation_requests = [
#       ['DELETE', %r{^/api/v1/auth/logout$}]
#     ]
#     jwt.expiration_time = 1.day.to_i
#   end
# end