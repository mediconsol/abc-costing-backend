#!/bin/bash

# Local Deployment Test Script for ABC Costing Backend
# This script tests the deployment process in a local environment

set -e

PROJECT_NAME="abc_costing_backend"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting local deployment test for $PROJECT_NAME..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        print_status "✓ $1"
    else
        print_error "✗ $1"
        exit 1
    fi
}

# Change to project directory
cd "$PROJECT_DIR"

print_status "Current directory: $(pwd)"

# Check if required files exist
print_status "Checking required files..."

required_files=(
    "Dockerfile"
    "docker-compose.yml" 
    ".env.example"
    "Gemfile"
    "config/application.rb"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "✓ Found: $file"
    else
        print_error "✗ Missing: $file"
        exit 1
    fi
done

# Check if .env exists, create from example if not
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Creating from .env.example..."
    cp .env.example .env
    
    # Generate secure keys for local testing
    print_status "Generating secure keys for local testing..."
    
    # Generate random passwords and keys
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    RAILS_MASTER_KEY=$(openssl rand -hex 32)
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)
    SIDEKIQ_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)
    
    # Update .env file with generated values
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/your_secure_password_here/$POSTGRES_PASSWORD/g" .env
        sed -i '' "s/your_master_key_here/$RAILS_MASTER_KEY/g" .env
        sed -i '' "s/your_secret_key_base_here/$SECRET_KEY_BASE/g" .env
        sed -i '' "s/your_jwt_secret_key_here/$DEVISE_JWT_SECRET_KEY/g" .env
        sed -i '' "s/your_sidekiq_password_here/$SIDEKIQ_PASSWORD/g" .env
    else
        # Linux
        sed -i "s/your_secure_password_here/$POSTGRES_PASSWORD/g" .env
        sed -i "s/your_master_key_here/$RAILS_MASTER_KEY/g" .env
        sed -i "s/your_secret_key_base_here/$SECRET_KEY_BASE/g" .env
        sed -i "s/your_jwt_secret_key_here/$DEVISE_JWT_SECRET_KEY/g" .env
        sed -i "s/your_sidekiq_password_here/$SIDEKIQ_PASSWORD/g" .env
    fi
    
    print_status "✓ Generated secure keys and updated .env file"
fi

print_status "Environment file check passed ✓"

# Check Docker installation
print_status "Checking Docker installation..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
else
    print_status "✓ Docker is installed: $(docker --version)"
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
else
    print_status "✓ Docker Compose is installed: $(docker-compose --version)"
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker first."
    exit 1
else
    print_status "✓ Docker daemon is running"
fi

# Clean up any existing containers
print_status "Cleaning up existing containers..."
docker-compose down --remove-orphans || true
docker system prune -f || true

# Build Docker images
print_status "Building Docker images..."
docker-compose build --no-cache
check_success "Docker images built successfully"

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p tmp/exports
mkdir -p log
mkdir -p ssl
check_success "Directories created"

# Start database and Redis first
print_status "Starting database and Redis..."
docker-compose up -d postgres redis
check_success "Database and Redis started"

# Wait for database to be ready
print_status "Waiting for database to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker-compose exec -T postgres pg_isready -U postgres &> /dev/null; then
        print_status "✓ Database is ready"
        break
    fi
    
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        print_error "Database failed to start within expected time"
        docker-compose logs postgres
        exit 1
    fi
    
    sleep 2
done

# Prepare database
print_status "Preparing database..."
docker-compose run --rm web bundle exec rails db:create
check_success "Database created"

docker-compose run --rm web bundle exec rails db:migrate
check_success "Database migrations completed"

# Start all services
print_status "Starting all services..."
docker-compose up -d
check_success "All services started"

# Wait for web service to be ready
print_status "Waiting for web service to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -f http://localhost:3000/up &> /dev/null; then
        print_status "✓ Web service is ready"
        break
    fi
    
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        print_error "Web service failed to start within expected time"
        docker-compose logs web
        exit 1
    fi
    
    sleep 3
done

# Display running services
print_status "Deployment test completed! Running services:"
docker-compose ps

print_status "Service URLs:"
echo "  🌐 Web Application: http://localhost:3000"
echo "  📊 Sidekiq Web UI: http://localhost:3000/sidekiq"
echo "  🗄️  Database: localhost:5432"
echo "  🔴 Redis: localhost:6379"

# Run health checks
print_status "Running health checks..."

# Check web service health
if curl -f http://localhost:3000/up &> /dev/null; then
    print_status "✓ Web service health check passed"
else
    print_error "✗ Web service health check failed"
fi

# Check database connection
if docker-compose exec -T web bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" &> /dev/null; then
    print_status "✓ Database connection check passed"
else
    print_error "✗ Database connection check failed"
fi

# Check Redis connection
if docker-compose exec -T web bundle exec rails runner "Redis.new(url: ENV['REDIS_URL']).ping" &> /dev/null; then
    print_status "✓ Redis connection check passed"
else
    print_error "✗ Redis connection check failed"
fi

# Run basic API test
print_status "Running basic API test..."
api_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/up)
if [ "$api_response" -eq 200 ]; then
    print_status "✓ Basic API test passed (HTTP 200)"
else
    print_warning "Basic API test returned HTTP $api_response"
fi

echo ""
print_status "🎉 Local deployment test completed successfully!"
echo ""
print_status "Next Steps:"
echo "  1. Test the application: http://localhost:3000"
echo "  2. Check logs: docker-compose logs -f"
echo "  3. Stop services: docker-compose down"
echo "  4. If everything looks good, proceed with production deployment"
echo ""
print_warning "Note: This is a local test environment. Production deployment requires additional security configurations."