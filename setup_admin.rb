#!/usr/bin/env ruby

# Railway Console에서 실행할 관리자 설정 스크립트
puts "🏥 ABC Costing Backend - 관리자 설정 스크립트"
puts "=" * 50

# 1. 관리자 사용자 생성
puts "1. 관리자 사용자 생성 중..."
admin_user = User.find_or_create_by(email: "admin@snuh.org") do |user|
  user.name = "서울대병원 관리자"
  user.password = "admin123456"
  user.password_confirmation = "admin123456"
end

if admin_user.persisted?
  puts "✅ 관리자 사용자 생성 완료: #{admin_user.email}"
else
  puts "❌ 관리자 사용자 생성 실패: #{admin_user.errors.full_messages.join(', ')}"
  exit 1
end

# 2. 첫 번째 병원 생성
puts "\n2. 병원 생성 중..."
hospital = Hospital.find_or_create_by(name: "서울대학교병원") do |h|
  h.address = "서울특별시 종로구 대학로 101"
  h.phone = "02-2072-2114"
  h.hospital_type = "general_hospital"
end

if hospital.persisted?
  puts "✅ 병원 생성 완료: #{hospital.name}"
else
  puts "❌ 병원 생성 실패: #{hospital.errors.full_messages.join(', ')}"
  exit 1
end

# 3. 관리자를 병원과 연결
puts "\n3. 관리자-병원 연결 중..."
hospital_user = HospitalUser.find_or_create_by(
  user: admin_user,
  hospital: hospital
) do |hu|
  hu.role = "admin"
end

if hospital_user.persisted?
  puts "✅ 관리자-병원 연결 완료: #{admin_user.name} → #{hospital.name} (#{hospital_user.role})"
else
  puts "❌ 관리자-병원 연결 실패: #{hospital_user.errors.full_messages.join(', ')}"
  exit 1
end

# 4. 기본 회계 기간 생성
puts "\n4. 기본 회계 기간 생성 중..."
period = Period.find_or_create_by(
  hospital: hospital,
  name: "2025년 1분기"
) do |p|
  p.start_date = Date.new(2025, 1, 1)
  p.end_date = Date.new(2025, 3, 31)
  p.is_active = true
  p.status = "planning"
end

if period.persisted?
  puts "✅ 기본 회계 기간 생성 완료: #{period.name}"
else
  puts "❌ 기본 회계 기간 생성 실패: #{period.errors.full_messages.join(', ')}"
  exit 1
end

# 5. 결과 요약
puts "\n" + "=" * 50
puts "🎉 관리자 설정 완료!"
puts "=" * 50
puts "📧 관리자 이메일: #{admin_user.email}"
puts "🔐 관리자 비밀번호: admin123456"
puts "🏥 병원명: #{hospital.name}"
puts "📅 활성 기간: #{period.name} (#{period.start_date} ~ #{period.end_date})"
puts "🔗 병원 ID: #{hospital.id}"
puts "👤 사용자 ID: #{admin_user.id}"
puts "\n🚀 이제 API 테스트를 진행할 수 있습니다!"

# 6. JWT 토큰 생성 테스트
puts "\n6. JWT 토큰 생성 테스트..."
begin
  require 'jwt'
  token = JWT.encode({ user_id: admin_user.id }, Rails.application.secret_key_base)
  puts "✅ JWT 토큰 생성 성공: #{token[0..50]}..."
rescue => e
  puts "❌ JWT 토큰 생성 실패: #{e.message}"
end

puts "\n✨ 설정 스크립트 실행 완료!"