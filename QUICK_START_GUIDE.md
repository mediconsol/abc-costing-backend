# 🚀 ABC Costing Backend - 빠른 시작 가이드

## ⚡ **5분 만에 프로덕션 배포하기**

### **1단계: 서버 준비 (2분)**

#### **DigitalOcean 추천 설정**
```
💰 비용: $24/월 (첫 2개월 무료 크레딧 $200)
⚡ 성능: 2 vCPUs, 4GB RAM, 80GB SSD
🌏 리전: Singapore (아시아 최적)
```

#### **즉시 시작하기**
1. **DigitalOcean 계정 생성**: https://digitalocean.com
2. **$200 무료 크레딧** 받기 (2개월 무료 사용)
3. **Create Droplet** 클릭
4. 설정 선택:
   - **OS**: Ubuntu 22.04 LTS
   - **Plan**: Basic - $24/month (2 vCPUs, 4GB RAM)
   - **Region**: Singapore
   - **Authentication**: SSH Key 또는 Password
5. **Create Droplet** 완료

### **2단계: 원클릭 배포 (3분)**

#### **서버 접속 후 한 줄 명령어 실행**
```bash
# SSH로 서버 접속
ssh root@YOUR_DROPLET_IP

# 원클릭 배포 실행 (모든 것이 자동으로 설치됩니다)
curl -fsSL https://raw.githubusercontent.com/your-repo/abc-costing/main/scripts/digitalocean_deploy.sh | bash
```

#### **또는 수동 배포**
```bash
# 프로젝트 다운로드 및 배포
git clone https://github.com/your-repo/abc-costing.git /opt/abc-costing
cd /opt/abc-costing/abc_costing_backend
chmod +x scripts/digitalocean_deploy.sh
sudo ./scripts/digitalocean_deploy.sh
```

---

## 🎯 **즉시 사용 가능한 완성된 기능들**

### **✅ 배포 완료 시 자동으로 포함되는 것들**

#### **🏥 병원 관리 시스템**
- 멀티테넌트 구조 (여러 병원 동시 지원)
- 사용자 역할 관리 (관리자/매니저/뷰어)
- JWT 기반 보안 인증

#### **💰 ABC 원가계산 엔진**
- 8단계 완전 자동화된 ABC 계산
- 백그라운드 작업으로 대용량 데이터 처리
- 실시간 진행 상황 추적

#### **📊 리포트 및 분석**
- 부서별/활동별/프로세스별 비용 분석
- Excel, CSV, PDF 내보내기
- KPI 대시보드 및 비교 분석

#### **🔧 운영 도구**
- 자동 백업 시스템 (매일 새벽 2시)
- 로그 로테이션
- 시스템 모니터링
- SSL 인증서 자동 갱신 준비

---

## 🔗 **배포 후 접속 URL들**

### **메인 서비스**
```
🌐 메인 API: https://yourdomain.com/api/v1/
🏥 헬스체크: https://yourdomain.com/up
📊 Sidekiq 모니터링: https://yourdomain.com/sidekiq
```

### **API 엔드포인트 예시**
```bash
# 로그인
POST https://yourdomain.com/api/v1/auth/login
{
  "user": {
    "email": "admin@hospital.com",
    "password": "password123"
  }
}

# ABC 계산 시작
POST https://yourdomain.com/api/v1/abc_calculations
{
  "abc_calculation": {
    "period_id": 1,
    "name": "2024년 1분기 ABC 분석"
  }
}

# 리포트 조회
GET https://yourdomain.com/api/v1/reports/departments?period_id=1
```

---

## 📋 **배포 후 5분 체크리스트**

### **✅ 필수 설정 (배포 직후)**

#### **1. 환경 변수 설정**
```bash
# .env 파일 편집
nano /opt/abc-costing/abc_costing_backend/.env

# 필수 변경 항목:
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com
```

#### **2. 도메인 DNS 설정**
```
A Record: @ → YOUR_SERVER_IP
A Record: api → YOUR_SERVER_IP  
A Record: www → YOUR_SERVER_IP
```

#### **3. SSL 인증서 발급**
```bash
# Let's Encrypt 무료 SSL 인증서
sudo certbot certonly --standalone -d yourdomain.com -d api.yourdomain.com

# 인증서 복사
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem /opt/abc-costing/abc_costing_backend/ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem /opt/abc-costing/abc_costing_backend/ssl/key.pem

# 서비스 재시작
cd /opt/abc-costing/abc_costing_backend && docker-compose restart
```

#### **4. 첫 번째 관리자 계정 생성**
```bash
# Rails 콘솔 접속
cd /opt/abc-costing/abc_costing_backend
docker-compose exec web bundle exec rails console

# 관리자 계정 생성
hospital = Hospital.create!(
  name: "서울대학교병원",
  code: "SNUH001", 
  address: "서울시 종로구",
  phone: "02-2072-2114",
  email: "admin@snuh.org"
)

user = User.create!(
  email: "admin@snuh.org",
  password: "admin123!",
  first_name: "관리자",
  last_name: "시스템",
  role: "admin",
  hospital: hospital
)

exit
```

---

## 🎉 **5분 후 완성된 것들**

### **즉시 사용 가능한 기능**
- ✅ 완전한 병원 ABC 원가계산 시스템
- ✅ 멀티테넌트 구조로 여러 병원 지원
- ✅ 보안이 강화된 API 시스템
- ✅ 자동 백업 및 모니터링
- ✅ SSL 인증서 및 방화벽 보안
- ✅ 고성능 백그라운드 작업 처리

### **바로 테스트할 수 있는 것들**
```bash
# 시스템 상태 확인
/opt/abc-costing/scripts/monitor.sh

# 헬스체크
curl https://yourdomain.com/up

# API 테스트
curl -X POST https://yourdomain.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"admin@snuh.org","password":"admin123!"}}'
```

---

## 🆘 **문제 해결 (1분 해결)**

### **서비스가 시작되지 않는 경우**
```bash
cd /opt/abc-costing/abc_costing_backend
docker-compose logs
docker-compose restart
```

### **데이터베이스 연결 오류**
```bash
docker-compose exec postgres psql -U postgres -d abc_costing_production
# 연결되면 \q로 종료
```

### **메모리 부족**
```bash
# 스왑 파일 생성 (1GB)
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 📞 **즉시 지원**

### **자동 모니터링**
- 시스템이 자동으로 오류를 감지하고 로그에 기록
- 매일 백업 자동 실행
- SSL 인증서 만료 30일 전 알림

### **원격 지원 준비**
```bash
# 시스템 상태 리포트 생성
/opt/abc-costing/scripts/monitor.sh > system_report.txt

# 최근 로그 확인
cd /opt/abc-costing/abc_costing_backend
docker-compose logs --tail=100 > recent_logs.txt
```

---

## 🚀 **결론: 5분 만에 완성!**

**이 가이드를 따르면 5분 내에 완전히 작동하는 병원 ABC 원가계산 시스템이 준비됩니다!**

1. ⏱️ **2분**: DigitalOcean 서버 생성
2. ⏱️ **3분**: 원클릭 배포 스크립트 실행
3. ✅ **완료**: 프로덕션급 시스템 운영 시작

**총 투자: $24/월로 엔터프라이즈급 시스템 운영** 🎯