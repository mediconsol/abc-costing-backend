class Api::V1::SetupController < ApplicationController
  skip_before_action :authenticate_user!
  
  # POST /api/v1/setup/admin
  def create_admin
    begin
      # 관리자 사용자 생성
      admin_user = User.create!(
        email: "admin@snuh.org",
        password: "admin123456",
        password_confirmation: "admin123456", 
        name: "서울대병원 관리자"
      )
      
      # 첫 번째 병원 생성
      hospital = Hospital.create!(
        name: "서울대학교병원",
        address: "서울특별시 종로구 대학로 101",
        phone: "02-2072-2114",
        hospital_type: "general_hospital"
      )
      
      # 관리자를 병원과 연결
      HospitalUser.create!(
        user: admin_user,
        hospital: hospital,
        role: "admin"
      )
      
      # 기본 회계 기간 생성
      period = Period.create!(
        hospital: hospital,
        name: "2025년 1분기",
        start_date: Date.new(2025, 1, 1),
        end_date: Date.new(2025, 3, 31),
        is_active: true,
        status: "planning"
      )
      
      render json: {
        success: true,
        message: "관리자 설정 완료",
        data: {
          admin: {
            id: admin_user.id,
            email: admin_user.email,
            name: admin_user.name
          },
          hospital: {
            id: hospital.id,
            name: hospital.name,
            type: hospital.hospital_type
          },
          period: {
            id: period.id,
            name: period.name,
            active: period.is_active
          }
        }
      }, status: :created
      
    rescue => e
      render json: {
        success: false,
        error: e.message,
        details: e.backtrace.first(3)
      }, status: :internal_server_error
    end
  end
end