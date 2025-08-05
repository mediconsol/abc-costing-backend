# 개발환경 시드 데이터

# 병원 생성
hospital = Hospital.find_or_create_by!(name: '서울대학교병원') do |h|
  h.address = '서울특별시 종로구 대학로 101'
  h.phone = '02-2072-2114'
  h.hospital_type = 'general_hospital'
end

puts "Created hospital: #{hospital.name}"

# 관리자 사용자 생성
admin_user = User.find_or_create_by!(email: 'admin@hospital.com') do |u|
  u.name = '시스템 관리자'
  u.password = 'password123'
  u.password_confirmation = 'password123'
end

puts "Created admin user: #{admin_user.email}"

# 매니저 사용자 생성
manager_user = User.find_or_create_by!(email: 'manager@hospital.com') do |u|
  u.name = '원가관리자'
  u.password = 'password123'
  u.password_confirmation = 'password123'
end

puts "Created manager user: #{manager_user.email}"

# 뷰어 사용자 생성
viewer_user = User.find_or_create_by!(email: 'viewer@hospital.com') do |u|
  u.name = '조회자'
  u.password = 'password123'
  u.password_confirmation = 'password123'
end

puts "Created viewer user: #{viewer_user.email}"

# 사용자-병원 관계 생성
HospitalUser.find_or_create_by!(user: admin_user, hospital: hospital) do |hu|
  hu.role = 'admin'
end

HospitalUser.find_or_create_by!(user: manager_user, hospital: hospital) do |hu|
  hu.role = 'manager'
end

HospitalUser.find_or_create_by!(user: viewer_user, hospital: hospital) do |hu|
  hu.role = 'viewer'
end

puts "Created hospital-user relationships"

# 기간 생성
period = Period.find_or_create_by!(hospital: hospital, name: '2024년 하반기') do |p|
  p.start_date = Date.new(2024, 7, 1)
  p.end_date = Date.new(2024, 12, 31)
  p.is_active = true
end

puts "Created period: #{period.name}"

# 기본 부서 생성
departments_data = [
  { code: 'D001', name: '내과', type: 'direct' },
  { code: 'D002', name: '외과', type: 'direct' },
  { code: 'D003', name: '영상의학과', type: 'direct' },
  { code: 'D004', name: '행정부서', type: 'indirect' },
  { code: 'D005', name: '시설관리부', type: 'indirect' }
]

departments_data.each do |dept_data|
  dept = Department.find_or_create_by!(
    hospital: hospital,
    period: period,
    code: dept_data[:code]
  ) do |d|
    d.name = dept_data[:name]
    d.department_type = dept_data[:type]
  end
  puts "Created department: #{dept.code} - #{dept.name}"
end

# 기본 계정과목 생성
accounts_data = [
  { code: '6110', name: '급여', category: 'salary', is_direct: false },
  { code: '6120', name: '상여금', category: 'salary', is_direct: false },
  { code: '6210', name: '의료재료비', category: 'material', is_direct: true },
  { code: '6220', name: '의약품비', category: 'material', is_direct: true },
  { code: '6310', name: '전기료', category: 'expense', is_direct: false },
  { code: '6320', name: '임차료', category: 'expense', is_direct: false }
]

accounts_data.each do |acc_data|
  acc = Account.find_or_create_by!(
    hospital: hospital,
    period: period,
    code: acc_data[:code]
  ) do |a|
    a.name = acc_data[:name]
    a.category = acc_data[:category]
    a.is_direct = acc_data[:is_direct]
  end
  puts "Created account: #{acc.code} - #{acc.name}"
end

# 기본 활동 생성
activities_data = [
  { code: 'ACT001', name: '외래진료', category: '의료' },
  { code: 'ACT002', name: '입원진료', category: '의료' },
  { code: 'ACT003', name: '수술', category: '의료' },
  { code: 'ACT004', name: '영상검사', category: '의료' },
  { code: 'ACT005', name: '행정업무', category: '관리' }
]

activities_data.each do |act_data|
  act = Activity.find_or_create_by!(
    hospital: hospital,
    period: period,
    code: act_data[:code]
  ) do |a|
    a.name = act_data[:name]
    a.category = act_data[:category]
  end
  puts "Created activity: #{act.code} - #{act.name}"
end

puts "\n✅ Seed data created successfully!"
puts "\n👤 Test Users:"
puts "- Admin: admin@hospital.com / password123"
puts "- Manager: manager@hospital.com / password123"
puts "- Viewer: viewer@hospital.com / password123"
puts "\n🏥 Hospital: #{hospital.name}"
puts "📅 Period: #{period.name} (Active)"
