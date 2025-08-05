# ABC Costing Backend 배포 가이드

## 📋 배포 체크리스트

### 1. 사전 준비 (Pre-deployment)

#### ✅ 서버 환경 요구사항
- **OS**: Ubuntu 20.04 LTS 이상 또는 CentOS 8 이상
- **CPU**: 최소 2 cores, 권장 4 cores
- **Memory**: 최소 4GB RAM, 권장 8GB RAM
- **Storage**: 최소 50GB SSD, 권장 100GB SSD
- **Network**: 공인 IP 및 도메인

#### ✅ 필수 소프트웨어 설치
```bash
# Docker 및 Docker Compose 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Git 설치
sudo apt-get update
sudo apt-get install -y git

# 방화벽 설정
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw enable
```

### 2. 환경 설정

#### ✅ 프로젝트 클론 및 설정
```bash
# 프로젝트 클론
git clone <your-repository-url> /opt/abc-costing
cd /opt/abc-costing/abc_costing_backend

# 환경 변수 설정
cp .env.example .env
```

#### ✅ .env 파일 필수 설정 항목
```bash
# 데이터베이스 설정
DATABASE_URL=postgresql://postgres:YOUR_SECURE_PASSWORD@postgres:5432/abc_costing_production
POSTGRES_PASSWORD=YOUR_SECURE_PASSWORD

# Redis 설정
REDIS_URL=redis://redis:6379/0

# Rails 시크릿 키 생성
RAILS_MASTER_KEY=$(openssl rand -hex 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)
DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)

# SMTP 설정 (이메일 알림용)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# Sidekiq Web UI 인증
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=$(openssl rand -base64 32)

# 성능 설정
ABC_CALCULATION_TIMEOUT=1800
REPORT_GENERATION_TIMEOUT=900
WEB_CONCURRENCY=2
MAX_THREADS=5

# 보안 설정
ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com
```

### 3. SSL 인증서 설정

#### ✅ Let's Encrypt 인증서 (무료)
```bash
# Certbot 설치
sudo apt-get install -y certbot

# 인증서 발급 (nginx 중지 후)
sudo certbot certonly --standalone -d yourdomain.com -d api.yourdomain.com

# 인증서 위치 확인
ls -la /etc/letsencrypt/live/yourdomain.com/
```

#### ✅ SSL 인증서 Docker 설정
```bash
# SSL 디렉토리 생성
mkdir -p ssl
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ssl/key.pem
sudo chown -R $USER:$USER ssl/
```

### 4. 로컬 테스트 배포

#### ✅ 개발 환경에서 테스트
```bash
# 빌드 테스트
docker-compose build

# 로컬 실행 테스트
docker-compose up -d postgres redis
sleep 10
docker-compose run --rm web bundle exec rails db:create db:migrate
docker-compose up -d

# 헬스체크
curl http://localhost:3000/up
```

### 5. 프로덕션 배포

#### ✅ 배포 스크립트 실행
```bash
# 배포 스크립트 권한 설정
chmod +x scripts/deploy.sh

# 프로덕션 배포 실행
./scripts/deploy.sh production
```

#### ✅ 수동 배포 단계 (스크립트 실패 시)
```bash
# 1. 이미지 빌드
docker-compose build --no-cache

# 2. 기존 컨테이너 중지
docker-compose down

# 3. 데이터베이스 및 Redis 시작
docker-compose up -d postgres redis

# 4. 데이터베이스 준비 대기
until docker-compose exec postgres pg_isready -U postgres; do sleep 2; done

# 5. 데이터베이스 마이그레이션
docker-compose run --rm web bundle exec rails db:create db:migrate

# 6. 모든 서비스 시작
docker-compose up -d

# 7. 상태 확인
docker-compose ps
```

### 6. 배포 후 검증

#### ✅ 기본 동작 확인
```bash
# 헬스체크
curl https://yourdomain.com/up

# API 테스트
curl -X POST https://yourdomain.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"test@example.com","password":"password"}}'

# Sidekiq 상태 확인
curl https://yourdomain.com/sidekiq
```

#### ✅ 로그 모니터링
```bash
# 전체 로그 확인
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f web
docker-compose logs -f sidekiq
docker-compose logs -f postgres
```

### 7. 모니터링 및 백업 설정

#### ✅ 로그 로테이션 설정
```bash
# /etc/logrotate.d/abc-costing 생성
sudo tee /etc/logrotate.d/abc-costing << EOF
/opt/abc-costing/abc_costing_backend/log/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f /opt/abc-costing/abc_costing_backend/docker-compose.yml exec web pkill -USR1 -f 'rails'
    endscript
}
EOF
```

#### ✅ 데이터베이스 백업 스크립트
```bash
# /opt/abc-costing/scripts/backup.sh 생성
cat > /opt/abc-costing/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/abc-costing/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="abc_costing_backup_${DATE}.sql"

mkdir -p $BACKUP_DIR

# PostgreSQL 백업
docker-compose -f /opt/abc-costing/abc_costing_backend/docker-compose.yml exec -T postgres \
  pg_dump -U postgres abc_costing_production > "${BACKUP_DIR}/${BACKUP_FILE}"

# 압축
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

# 30일 이상된 백업 파일 삭제
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
EOF

chmod +x /opt/abc-costing/scripts/backup.sh

# Cron 작업 추가 (매일 새벽 2시)
echo "0 2 * * * /opt/abc-costing/scripts/backup.sh" | sudo crontab -
```

### 8. 보안 강화

#### ✅ 방화벽 및 보안 설정
```bash
# 불필요한 포트 차단
sudo ufw deny 3000  # Rails 직접 접근 차단
sudo ufw deny 5432  # PostgreSQL 직접 접근 차단
sudo ufw deny 6379  # Redis 직접 접근 차단

# SSH 보안 강화
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

#### ✅ 시스템 모니터링
```bash
# htop 설치 (시스템 모니터링)
sudo apt-get install -y htop

# Docker 상태 모니터링 스크립트
cat > /opt/abc-costing/scripts/monitor.sh << 'EOF'
#!/bin/bash
echo "=== Docker Containers Status ==="
docker-compose -f /opt/abc-costing/abc_costing_backend/docker-compose.yml ps

echo "=== System Resources ==="
free -h
df -h

echo "=== Recent Logs ==="
docker-compose -f /opt/abc-costing/abc_costing_backend/docker-compose.yml logs --tail=10 web
EOF

chmod +x /opt/abc-costing/scripts/monitor.sh
```

## 🚨 문제 해결 가이드

### 일반적인 문제들

#### Database Connection Error
```bash
# PostgreSQL 컨테이너 상태 확인
docker-compose logs postgres

# 수동 연결 테스트
docker-compose exec postgres psql -U postgres -d abc_costing_production
```

#### Memory Issues
```bash
# 메모리 사용량 확인
docker stats

# Sidekiq worker 수 조정
# docker-compose.yml에서 SIDEKIQ_CONCURRENCY 값 조정
```

#### SSL Certificate Issues
```bash
# 인증서 갱신
sudo certbot renew

# Nginx 재시작
docker-compose restart nginx
```

## 📞 지원 및 연락처

- **기술 지원**: 개발팀
- **운영 문의**: 시스템 관리자
- **긴급 상황**: 24/7 지원 라인

---

**배포 완료 후 반드시 모든 기능을 테스트하고 모니터링 시스템을 확인하세요!**