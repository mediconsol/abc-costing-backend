#!/bin/bash

# ABC Costing Backend Deployment Script
# Usage: ./scripts/deploy.sh [environment]

set -e

ENVIRONMENT=${1:-production}
PROJECT_NAME="abc_costing_backend"

echo "🚀 Starting deployment for $PROJECT_NAME in $ENVIRONMENT environment..."

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

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Creating from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_warning "Please edit .env file with your actual values before continuing."
        exit 1
    else
        print_error ".env.example file not found. Cannot create .env file."
        exit 1
    fi
fi

print_status "Environment file check passed ✓"

# Load environment variables
source .env

# Validate required environment variables
required_vars=("RAILS_MASTER_KEY" "SECRET_KEY_BASE" "DATABASE_URL" "REDIS_URL")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set in .env file"
        exit 1
    fi
done

print_status "Environment variables validation passed ✓"

# Build Docker images
print_status "Building Docker images..."
docker-compose build --no-cache

# Stop existing containers
print_status "Stopping existing containers..."
docker-compose down

# Start database and Redis first
print_status "Starting database and Redis..."
docker-compose up -d postgres redis

# Wait for database to be ready
print_status "Waiting for database to be ready..."
until docker-compose exec postgres pg_isready -U postgres; do
    sleep 2
done

print_status "Database is ready ✓"

# Run database migrations
print_status "Running database migrations..."
docker-compose run --rm web bundle exec rails db:create db:migrate

# Seed initial data if needed
if [ "$ENVIRONMENT" = "production" ] && [ -f "db/seeds.rb" ]; then
    print_warning "Running database seeds..."
    docker-compose run --rm web bundle exec rails db:seed
fi

# Start all services
print_status "Starting all services..."
docker-compose up -d

# Wait for web service to be healthy
print_status "Waiting for web service to be healthy..."
for i in {1..30}; do
    if docker-compose exec web curl -f http://localhost:3000/up &> /dev/null; then
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Web service failed to start properly"
        docker-compose logs web
        exit 1
    fi
    sleep 2
done

print_status "Web service is healthy ✓"

# Start Sidekiq worker
print_status "Starting Sidekiq worker..."
docker-compose up -d sidekiq

# Display running services
print_status "Deployment completed! Running services:"
docker-compose ps

print_status "Service URLs:"
echo "  🌐 Web Application: http://localhost:3000"
echo "  📊 Sidekiq Web UI: http://localhost:3000/sidekiq (if enabled)"
echo "  🗄️  Database: localhost:5432"
echo "  🔴 Redis: localhost:6379"

print_status "To view logs, run: docker-compose logs -f"
print_status "To stop services, run: docker-compose down"

# Run health checks
print_status "Running health checks..."

# Check web service
if curl -f http://localhost:3000/up &> /dev/null; then
    print_status "✓ Web service health check passed"
else
    print_error "✗ Web service health check failed"
fi

# Check database connection
if docker-compose exec web bundle exec rails runner "ActiveRecord::Base.connection" &> /dev/null; then
    print_status "✓ Database connection check passed"
else
    print_error "✗ Database connection check failed"
fi

# Check Redis connection
if docker-compose exec web bundle exec rails runner "Redis.new(url: ENV['REDIS_URL']).ping" &> /dev/null; then
    print_status "✓ Redis connection check passed"
else
    print_error "✗ Redis connection check failed"
fi

print_status "🎉 Deployment completed successfully!"

# Optional: Run a basic API test
if command -v curl &> /dev/null; then
    print_status "Running basic API test..."
    if curl -f -s http://localhost:3000/up | grep -q "success"; then
        print_status "✓ Basic API test passed"
    else
        print_warning "Basic API test failed - manual verification recommended"
    fi
fi

echo ""
print_status "Deployment Summary:"
echo "  Environment: $ENVIRONMENT"
print_status "  Project: $PROJECT_NAME"
echo "  Services: web, sidekiq, postgres, redis"
echo "  Status: ✓ Running"
echo ""
print_warning "Next Steps:"
echo "  1. Verify all services are running: docker-compose ps"
echo "  2. Check application logs: docker-compose logs -f web"
echo "  3. Test API endpoints manually"
echo "  4. Set up monitoring and alerts"
echo "  5. Configure SSL/TLS for production"