# Railway Environment Variables Setup

Railway 배포를 위해 다음 환경변수들을 설정해야 합니다:

## 필수 환경변수

### 1. Rails Master Key
```
RAILS_MASTER_KEY=2885fae484ce53c4d9b98db7c179544e
```

### 2. JWT Secret Key (32자 이상)
```
DEVISE_JWT_SECRET_KEY=2885fae484ce53c4d9b98db7c179544e1234567890abcdef
```

### 3. Rails Environment
```
RAILS_ENV=production
```

### 4. Redis URL (Sidekiq용)
```
REDIS_URL=redis://red-xxxxx:6379
```

## Railway에서 환경변수 설정 방법

1. Railway 대시보드에서 프로젝트 선택
2. Variables 탭 클릭
3. 위의 환경변수들을 추가

## 데이터베이스
Railway에서 PostgreSQL 서비스를 추가하면 `DATABASE_URL`이 자동으로 설정됩니다.

## 확인 방법
배포 후 로그에서 다음 메시지 확인:
- "🚂 Railway: Checking database..."
- "Running database migrations..."
- "✅ Database setup complete"
- "=> Booting Puma"
- "=> Rails 8.0.2 application starting in production"