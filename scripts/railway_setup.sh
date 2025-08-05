#!/bin/bash

# Railway 배포 준비 스크립트
# ABC Costing Backend를 Railway에 배포하기 위한 모든 설정을 자동화

set -e

echo "🚂 Railway 배포 준비 중..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_header "Railway CLI 설치 확인"

# Node.js 및 npm 확인
if ! command -v npm &> /dev/null; then
    print_error "npm이 설치되지 않았습니다. Node.js를 먼저 설치해주세요."
    echo "다운로드: https://nodejs.org/"
    exit 1
fi

# Railway CLI 설치
if ! command -v railway &> /dev/null; then
    print_status "Railway CLI 설치 중..."
    npm install -g @railway/cli
else
    print_status "Railway CLI가 이미 설치되어 있습니다."
fi

print_header "Railway 로그인"

# Railway 로그인 확인
if ! railway whoami &> /dev/null; then
    print_status "Railway에 로그인해주세요..."
    railway login
else
    print_status "Railway 로그인 확인됨: $(railway whoami)"
fi

print_header "프로젝트 설정 파일 준비"

# Railway 설정 파일 생성 또는 확인
if [ ! -f "railway.json" ]; then
    print_status "railway.json 생성 중..."
    cat > railway.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile.railway"
  },
  "deploy": {
    "numReplicas": 1,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
EOF
    print_status "✓ railway.json 생성 완료"
else
    print_status "✓ railway.json 이미 존재"
fi

# Procfile 생성 (대안적 배포 방법)
if [ ! -f "Procfile" ]; then
    print_status "Procfile 생성 중..."
    cat > Procfile << 'EOF'
web: bundle exec rails server -p $PORT -b 0.0.0.0
worker: bundle exec sidekiq
EOF
    print_status "✓ Procfile 생성 완료"
else
    print_status "✓ Procfile 이미 존재"
fi

print_header "환경 변수 준비"

# 환경 변수 생성
print_status "환경 변수 생성 중..."

RAILS_MASTER_KEY=$(openssl rand -hex 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)
DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)
SIDEKIQ_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)

# 환경 변수 파일 생성 (로컬 참조용)
cat > .env.railway << EOF
# Railway 환경 변수 (복사해서 Railway 대시보드에 설정)

# Rails 기본 설정
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true

# 보안 키들
RAILS_MASTER_KEY=$RAILS_MASTER_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE
DEVISE_JWT_SECRET_KEY=$DEVISE_JWT_SECRET_KEY

# Sidekiq 설정
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=$SIDEKIQ_PASSWORD

# ABC Costing 설정
ABC_CALCULATION_TIMEOUT=1800
REPORT_GENERATION_TIMEOUT=900
EXPORT_FILE_RETENTION_DAYS=7

# 성능 설정
WEB_CONCURRENCY=2
MAX_THREADS=5
RAILS_MAX_THREADS=5

# 이메일 설정 (실제 값으로 변경 필요)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS=true

# 보안 설정 (실제 도메인으로 변경 필요)
ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com

# Railway에서 자동 생성됨 (수동 설정 불필요)
# DATABASE_URL=postgresql://...
# REDIS_URL=redis://...
EOF

print_status "✓ 환경 변수 파일 생성: .env.railway"

print_header "Railway 프로젝트 초기화"

# Railway 프로젝트 초기화
if [ ! -f ".railway.json" ]; then
    print_status "Railway 프로젝트 초기화 중..."
    railway init --name "abc-costing-backend"
    print_status "✓ Railway 프로젝트 초기화 완료"
else
    print_status "✓ Railway 프로젝트가 이미 초기화되어 있습니다."
fi

print_header "데이터베이스 및 Redis 추가"

# PostgreSQL 추가
print_status "PostgreSQL 데이터베이스 추가 중..."
railway add postgresql || print_warning "PostgreSQL이 이미 추가되어 있거나 추가에 실패했습니다."

# Redis 추가
print_status "Redis 추가 중..."
railway add redis || print_warning "Redis가 이미 추가되어 있거나 추가에 실패했습니다."

print_header "환경 변수 설정"

# 환경 변수 설정
print_status "필수 환경 변수 설정 중..."

railway variables set RAILS_ENV=production
railway variables set RAILS_LOG_TO_STDOUT=true
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_MASTER_KEY="$RAILS_MASTER_KEY"
railway variables set SECRET_KEY_BASE="$SECRET_KEY_BASE"
railway variables set DEVISE_JWT_SECRET_KEY="$DEVISE_JWT_SECRET_KEY"
railway variables set SIDEKIQ_USERNAME=admin
railway variables set SIDEKIQ_PASSWORD="$SIDEKIQ_PASSWORD"
railway variables set ABC_CALCULATION_TIMEOUT=1800
railway variables set REPORT_GENERATION_TIMEOUT=900
railway variables set EXPORT_FILE_RETENTION_DAYS=7
railway variables set WEB_CONCURRENCY=2
railway variables set MAX_THREADS=5
railway variables set RAILS_MAX_THREADS=5

print_status "✓ 환경 변수 설정 완료"

print_header "Sidekiq Worker 서비스 생성"

# Sidekiq 서비스 설정 정보 출력
print_status "Sidekiq Worker 서비스 수동 생성 가이드:"
echo ""
echo "Railway 대시보드에서 다음 단계를 수행하세요:"
echo "1. 'New' → 'Empty Service' 클릭"
echo "2. Service Name: abc-costing-sidekiq"
echo "3. Connect Repository → 같은 GitHub repo 선택"
echo "4. Settings → Start Command: bundle exec sidekiq"
echo "5. Variables → 메인 서비스와 동일한 환경변수 복사"
echo ""

print_header "배포 준비 완료!"

echo ""
print_status "🎉 Railway 배포 준비가 완료되었습니다!"
echo ""
print_status "다음 단계:"
echo ""
echo "1. 📝 이메일 설정 업데이트:"
echo "   railway variables set SMTP_USERNAME=your_email@gmail.com"
echo "   railway variables set SMTP_PASSWORD=your_app_password"
echo "   railway variables set SMTP_DOMAIN=yourdomain.com"
echo ""
echo "2. 🌐 도메인 설정 (선택사항):"
echo "   railway variables set ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com"
echo ""
echo "3. 🚀 배포 실행:"
echo "   railway up"
echo ""
echo "4. 📊 Sidekiq Worker 서비스 수동 생성 (Railway 대시보드에서)"
echo ""
echo "5. ✅ 배포 확인:"
echo "   railway logs"
echo "   railway status"
echo ""
print_status "📱 Railway 대시보드: https://railway.app/dashboard"
print_status "🔗 배포 후 URL: https://abc-costing-backend-production.up.railway.app"
echo ""
print_warning "참고사항:"
print_warning "- .env.railway 파일에 생성된 키들을 안전하게 보관하세요"
print_warning "- Railway 대시보드에서 실시간 로그와 메트릭을 확인할 수 있습니다"
print_warning "- 첫 배포는 빌드 시간으로 인해 5-10분 소요될 수 있습니다"
echo ""
print_status "🚂 Railway 배포를 시작하려면 'railway up' 명령을 실행하세요!"