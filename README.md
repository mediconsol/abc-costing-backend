# 🏥 ABC Costing Backend

**병원 활동기준원가(ABC) 계산 시스템 - 백엔드 API**

## 🚀 **즉시 배포 가능**

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/new?template=https://github.com/mediconsol/abc-costing-backend)

## 📋 **프로젝트 개요**

병원의 활동기준원가(Activity-Based Costing) 계산을 위한 완전한 백엔드 시스템입니다. 멀티테넌트 아키텍처로 여러 병원의 원가 데이터를 안전하게 관리하고, 8단계 ABC 계산 엔진을 통해 정확한 원가 분석을 제공합니다.

## ✨ **주요 기능**

### 🏥 **병원 관리**
- 멀티테넌트 병원 시스템
- 병원별 독립적인 데이터 관리
- 역할 기반 접근 제어 (RBAC)

### 💰 **ABC 원가계산**
- 8단계 활동기준원가 계산 엔진
- 부서별 원가 할당
- 활동별 원가 분석
- 프로세스별 원가 매핑

### 📊 **데이터 관리**
- 부서 계층 구조 관리
- 계정과목 관리
- 활동 및 프로세스 정의
- 원동력(Driver) 기반 할당

### 🔐 **보안 및 인증**
- JWT 기반 인증 시스템
- Devise 통합
- 병원별 사용자 권한 관리

### 📈 **리포트 및 분석**
- Excel/CSV/PDF 내보내기
- KPI 대시보드
- 실시간 계산 진행 추적
- 백그라운드 작업 처리

## 🛠 **기술 스택**

- **Framework**: Rails 8.0.2 (Ruby 3.3.7)
- **Database**: PostgreSQL (Production) / SQLite (Development)
- **Background Jobs**: Sidekiq + Redis
- **Authentication**: Devise + JWT
- **API**: RESTful JSON API
- **Deployment**: Railway (Docker)
- **Testing**: RSpec + FactoryBot

## 🚀 **빠른 시작**

### **로컬 개발**

```bash
# 저장소 클론
git clone https://github.com/mediconsol/abc-costing-backend.git
cd abc-costing-backend

# 의존성 설치
bundle install

# 데이터베이스 설정
rails db:create db:migrate db:seed

# 서버 실행
rails server
```

### **Railway 배포**

1. [Railway](https://railway.app)에서 "Deploy from GitHub repo" 선택
2. 이 저장소 연결
3. PostgreSQL 및 Redis 서비스 자동 추가
4. 환경변수 설정
5. 배포 완료!

## 📚 **API 문서**

### **인증**
```http
POST /api/v1/auth/login
POST /api/v1/auth/signup
DELETE /api/v1/auth/logout
GET /api/v1/auth/me
```

### **병원 관리**
```http
GET /api/v1/hospitals
POST /api/v1/hospitals
GET /api/v1/hospitals/:id
PUT /api/v1/hospitals/:id
DELETE /api/v1/hospitals/:id
```

### **ABC 계산**
```http
POST /api/v1/hospitals/:hospital_id/periods/:period_id/allocations/execute
GET /api/v1/hospitals/:hospital_id/periods/:period_id/allocations/status/:job_id
GET /api/v1/hospitals/:hospital_id/periods/:period_id/allocations/results
```

### **리포트**
```http
GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/departments
GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/activities
GET /api/v1/hospitals/:hospital_id/periods/:period_id/reports/kpi
POST /api/v1/hospitals/:hospital_id/periods/:period_id/reports/export
```

## 🏗 **시스템 아키텍처**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API   │    │   Database      │
│   (Next.js)     │◄──►│   (Rails)       │◄──►│   (PostgreSQL)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Background    │
                       │   Jobs (Sidekiq)│
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Cache (Redis) │
                       └─────────────────┘
```

## 📊 **ABC 계산 프로세스**

1. **원가 입력** - 부서별 직접원가 입력
2. **활동 정의** - 병원 활동 정의 및 분류
3. **원동력 설정** - 원가 할당 기준 설정
4. **매핑 설정** - 계정-활동, 활동-프로세스 매핑
5. **작업비율 입력** - 직원별 작업 시간 비율
6. **1차 할당** - 직접원가를 활동별로 할당
7. **2차 할당** - 활동원가를 프로세스별로 할당
8. **최종 계산** - 단위원가 및 수익성 분석

## 🔧 **개발 환경 설정**

### **필수 요구사항**
- Ruby 3.3.7
- Rails 8.0.2
- PostgreSQL (Production)
- Redis (Background Jobs)

### **환경변수**
```bash
RAILS_ENV=production
RAILS_MASTER_KEY=<master_key>
SECRET_KEY_BASE=<secret_key>
DATABASE_URL=<postgresql_url>
REDIS_URL=<redis_url>
DEVISE_JWT_SECRET_KEY=<jwt_secret>
```

## 🧪 **테스트**

```bash
# 전체 테스트 실행
bundle exec rspec

# 특정 테스트 실행
bundle exec rspec spec/models/
bundle exec rspec spec/controllers/
```

## 📦 **배포**

### **Railway (권장)**
- 자동 CI/CD
- PostgreSQL + Redis 포함
- SSL 인증서 자동 발급
- 월 $5 (첫 달 무료)

### **Docker**
```bash
docker build -t abc-costing-backend .
docker run -p 3000:3000 abc-costing-backend
```

## 🤝 **기여하기**

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 **라이선스**

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 **지원**

- **이슈**: [GitHub Issues](https://github.com/mediconsol/abc-costing-backend/issues)
- **문서**: [Wiki](https://github.com/mediconsol/abc-costing-backend/wiki)
- **이메일**: support@mediconsol.com

---

**🏥 병원 ABC 원가계산 시스템 - 정확하고 효율적인 원가 관리의 시작**
