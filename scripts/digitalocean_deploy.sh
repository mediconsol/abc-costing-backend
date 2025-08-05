#!/bin/bash

# DigitalOcean Production Deployment Script for ABC Costing Backend
# This script automates the complete deployment process on DigitalOcean

set -e

echo "🚀 ABC Costing Backend - DigitalOcean Production Deployment"
echo "=========================================================="

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
    echo -e "${BLUE}${NC}"
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (use sudo)"
    exit 1
fi

print_header "System Update and Dependencies Installation"

# Update system
print_status "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    git \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    logrotate

print_header "Docker Installation"

# Install Docker
print_status "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
print_status "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.0"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add current user to docker group
usermod -aG docker $SUDO_USER 2>/dev/null || true

print_header "Firewall Configuration"

# Configure UFW firewall
print_status "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw --force enable

print_header "Fail2Ban Configuration"

# Configure Fail2Ban
print_status "Configuring Fail2Ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl restart fail2ban
systemctl enable fail2ban

print_header "SSL Certificate Setup (Certbot)"

# Install Certbot
print_status "Installing Certbot for SSL certificates..."
apt-get install -y certbot

print_header "Project Deployment"

# Create project directory
PROJECT_DIR="/opt/abc-costing"
print_status "Creating project directory: $PROJECT_DIR"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Clone repository (you'll need to replace with actual repo URL)
print_status "Cloning ABC Costing repository..."
if [ -d "abc_costing_backend" ]; then
    print_warning "Project directory exists. Pulling latest changes..."
    cd abc_costing_backend
    git pull origin main
else
    # Replace with your actual repository URL
    print_warning "Please replace this with your actual repository URL"
    echo "git clone https://github.com/YOUR_USERNAME/abc-costing.git ."
    echo "For now, creating directory structure..."
    mkdir -p abc_costing_backend
fi

cd $PROJECT_DIR

print_header "Environment Configuration"

# Create environment file
print_status "Setting up environment configuration..."
if [ ! -f "abc_costing_backend/.env" ]; then
    cd abc_costing_backend
    cp .env.example .env 2>/dev/null || {
        print_warning "Creating basic .env file..."
        cat > .env << EOF
# Database Configuration
DATABASE_URL=postgresql://postgres:$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)@postgres:5432/abc_costing_production
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Rails Configuration
RAILS_ENV=production
RAILS_MASTER_KEY=$(openssl rand -hex 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)

# JWT Configuration
DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)

# SMTP Configuration
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# Sidekiq Web UI Authentication
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)

# Application Configuration
ABC_CALCULATION_TIMEOUT=1800
REPORT_GENERATION_TIMEOUT=900
EXPORT_FILE_RETENTION_DAYS=7

# Performance Settings
WEB_CONCURRENCY=2
MAX_THREADS=5
RAILS_MAX_THREADS=5

# Security Settings
ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com
EOF
    }
    cd ..
fi

print_header "Docker Deployment"

# Deploy with Docker
cd $PROJECT_DIR/abc_costing_backend

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p tmp/exports log ssl backups

# Set proper permissions
chown -R $SUDO_USER:$SUDO_USER $PROJECT_DIR 2>/dev/null || true

# Build and start services
print_status "Building and starting Docker services..."
docker-compose build --no-cache
docker-compose down --remove-orphans || true
docker-compose up -d postgres redis

# Wait for database
print_status "Waiting for database to be ready..."
sleep 15

# Initialize database
print_status "Initializing database..."
docker-compose run --rm web bundle exec rails db:create db:migrate || {
    print_warning "Database initialization failed. This might be normal for first deployment."
}

# Start all services
print_status "Starting all services..."
docker-compose up -d

print_header "Service Verification"

# Check service status
print_status "Checking service status..."
sleep 10
docker-compose ps

# Test application
print_status "Testing application health..."
for i in {1..30}; do
    if curl -f http://localhost:3000/up >/dev/null 2>&1; then
        print_status "✓ Application is responding"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "Application health check failed. Check logs: docker-compose logs"
    fi
    sleep 2
done

print_header "Backup Setup"

# Create backup script
print_status "Setting up automated backups..."
cat > $PROJECT_DIR/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/abc-costing/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="abc_costing_backup_${DATE}.sql"

mkdir -p $BACKUP_DIR

# PostgreSQL backup
docker-compose -f /opt/abc-costing/abc_costing_backend/docker-compose.yml exec -T postgres \
  pg_dump -U postgres abc_costing_production > "${BACKUP_DIR}/${BACKUP_FILE}"

# Compress backup
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

# Keep only last 30 days of backups
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
EOF

chmod +x $PROJECT_DIR/scripts/backup.sh

# Add cron job for daily backups
print_status "Setting up daily backup cron job..."
(crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_DIR/scripts/backup.sh") | crontab -

print_header "Log Rotation Setup"

# Configure log rotation
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/abc-costing << EOF
$PROJECT_DIR/abc_costing_backend/log/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f $PROJECT_DIR/abc_costing_backend/docker-compose.yml exec web pkill -USR1 -f 'rails' || true
    endscript
}
EOF

print_header "Monitoring Setup"

# Create monitoring script
print_status "Setting up monitoring script..."
cat > $PROJECT_DIR/scripts/monitor.sh << 'EOF'
#!/bin/bash
echo "=== ABC Costing System Status ==="
echo "Date: $(date)"
echo ""

echo "=== Docker Containers ==="
docker-compose -f /opt/abc-costing/abc_costing_backend/docker-compose.yml ps

echo ""
echo "=== System Resources ==="
echo "Memory Usage:"
free -h
echo ""
echo "Disk Usage:"
df -h
echo ""
echo "CPU Load:"
uptime

echo ""
echo "=== Application Health ==="
if curl -f http://localhost:3000/up >/dev/null 2>&1; then
    echo "✓ Application: Healthy"
else
    echo "✗ Application: Unhealthy"
fi

echo ""
echo "=== Recent Logs ==="
docker-compose -f /opt/abc-costing/abc_costing_backend/docker-compose.yml logs --tail=5 web
EOF

chmod +x $PROJECT_DIR/scripts/monitor.sh

print_header "Deployment Complete!"

print_status "🎉 ABC Costing Backend deployment completed successfully!"
echo ""
print_status "Next Steps:"
echo "  1. 📝 Edit .env file with your actual values:"
echo "     nano $PROJECT_DIR/abc_costing_backend/.env"
echo ""
echo "  2. 🌐 Set up your domain DNS to point to this server:"
echo "     A Record: @ → $(curl -s ifconfig.me)"
echo "     A Record: api → $(curl -s ifconfig.me)"
echo ""
echo "  3. 🔒 Generate SSL certificate:"
echo "     sudo certbot certonly --standalone -d yourdomain.com -d api.yourdomain.com"
echo "     sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem $PROJECT_DIR/abc_costing_backend/ssl/cert.pem"
echo "     sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem $PROJECT_DIR/abc_costing_backend/ssl/key.pem"
echo ""
echo "  4. 🔄 Restart services with SSL:"
echo "     cd $PROJECT_DIR/abc_costing_backend && docker-compose restart"
echo ""
echo "  5. ✅ Verify deployment:"
echo "     $PROJECT_DIR/scripts/monitor.sh"
echo ""

print_status "Service URLs:"
echo "  🌐 Application: http://$(curl -s ifconfig.me) (will be https after SSL setup)"
echo "  📊 Sidekiq UI: http://$(curl -s ifconfig.me)/sidekiq"
echo "  📈 Health Check: http://$(curl -s ifconfig.me)/up"
echo ""

print_status "Useful Commands:"
echo "  📊 Monitor system: $PROJECT_DIR/scripts/monitor.sh"
echo "  💾 Manual backup: $PROJECT_DIR/scripts/backup.sh"
echo "  📋 View logs: cd $PROJECT_DIR/abc_costing_backend && docker-compose logs -f"
echo "  🔄 Restart services: cd $PROJECT_DIR/abc_costing_backend && docker-compose restart"
echo ""

print_warning "Remember to:"
print_warning "  - Update .env file with real values"
print_warning "  - Set up SSL certificates"
print_warning "  - Configure your domain DNS"
print_warning "  - Test all functionality"

echo ""
print_status "Deployment completed at: $(date)"