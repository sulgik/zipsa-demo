#!/bin/bash
set -e

# Zipsa Demo Deployment Script
# Usage: ./deploy.sh [fly|vps]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_env() {
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_error ".env file not found!"
        echo "Please copy .env.example to .env and fill in your values:"
        echo "  cp .env.example .env"
        echo "  nano .env"
        exit 1
    fi

    # Check required variables
    source "$PROJECT_DIR/.env"

    if [ -z "$ANTHROPIC_API_KEY" ] || [ "$ANTHROPIC_API_KEY" = "your-key-here" ]; then
        log_error "ANTHROPIC_API_KEY not set in .env"
        exit 1
    fi

    if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "change-me" ]; then
        log_error "ADMIN_TOKEN not set in .env (don't use 'change-me')"
        exit 1
    fi

    log_info "Environment variables validated"
}

deploy_fly() {
    log_info "Deploying to Fly.io..."

    # Check if fly CLI is installed
    if ! command -v fly &> /dev/null; then
        log_error "Fly CLI not found. Install it with:"
        echo "  curl -L https://fly.io/install.sh | sh"
        exit 1
    fi

    # Check if logged in
    if ! fly auth whoami &> /dev/null; then
        log_warn "Not logged in to Fly.io. Running 'fly auth login'..."
        fly auth login
    fi

    cd "$PROJECT_DIR"

    # Create fly.toml if it doesn't exist
    if [ ! -f "fly.toml" ]; then
        log_info "Creating Fly.io configuration..."
        cat > fly.toml << 'EOF'
app = "zipsa-demo"
primary_region = "sjc"

[build]
  dockerfile = "Dockerfile.fly"

[env]
  DEMO_MODE = "true"
  LOG_DIR = "/app/logs"

[http_service]
  internal_port = 8000
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1

[[services]]
  protocol = "tcp"
  internal_port = 7861

  [[services.ports]]
    port = 7861
    handlers = ["tls", "http"]

[mounts]
  source = "zipsa_data"
  destination = "/app/data"
EOF
        log_info "Created fly.toml"
    fi

    # Create Fly Dockerfile if it doesn't exist
    if [ ! -f "Dockerfile.fly" ]; then
        log_info "Creating Fly.io Dockerfile..."
        cat > Dockerfile.fly << 'EOF'
# Fly.io optimized Dockerfile for Zipsa
FROM python:3.11-slim

WORKDIR /app

# Install git to clone zipsa
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

# Clone zipsa from GitHub
RUN git clone https://github.com/sulgik/zipsa.git /app

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create data directories
RUN mkdir -p /app/logs /app/data

EXPOSE 8000 7861

# Start both services
CMD ["python", "-m", "zipsa.main"]
EOF
        log_info "Created Dockerfile.fly"
    fi

    # Set secrets
    log_info "Setting Fly.io secrets..."
    source "$PROJECT_DIR/.env"

    fly secrets set \
        ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
        ADMIN_TOKEN="$ADMIN_TOKEN" \
        ${LOCAL_HOST:+LOCAL_HOST="$LOCAL_HOST"} \
        ${LOCAL_API_KEY:+LOCAL_API_KEY="$LOCAL_API_KEY"} \
        ${LOCAL_MODEL:+LOCAL_MODEL="$LOCAL_MODEL"} \
        --app zipsa-demo 2>/dev/null || true

    # Deploy
    log_info "Deploying application..."
    fly deploy

    log_info "Deployment complete!"
    echo ""
    echo "Your Zipsa demo is now live at:"
    echo "  API: https://zipsa-demo.fly.dev"
    echo "  Monitor: https://zipsa-demo.fly.dev:7861 (requires ADMIN_TOKEN)"
    echo ""
    echo "To check status: fly status"
    echo "To view logs: fly logs"
}

deploy_vps() {
    log_info "Deploying to VPS with Docker Compose..."

    cd "$PROJECT_DIR"

    # Create necessary directories
    mkdir -p logs data nginx/ssl nginx/certbot

    # Pull latest images and start
    log_info "Pulling latest images..."
    docker-compose pull 2>/dev/null || true

    log_info "Building and starting services..."
    docker-compose up -d --build

    # Wait for services to start
    log_info "Waiting for services to start..."
    sleep 10

    # Check health
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        log_info "Zipsa API is healthy"
    else
        log_warn "Zipsa API health check failed - it may still be starting"
    fi

    log_info "Deployment complete!"
    echo ""
    echo "Your Zipsa demo is now running:"
    echo "  API: http://localhost:80 (or your server IP)"
    echo "  Monitor: http://localhost:80/monitor (requires Authorization header)"
    echo ""
    echo "For HTTPS with Let's Encrypt:"
    echo "  1. Point your domain to this server"
    echo "  2. Run: docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d your-domain.com"
    echo "  3. Uncomment the HTTPS server block in nginx/nginx.conf"
    echo "  4. Restart nginx: docker-compose restart nginx"
    echo ""
    echo "To check status: docker-compose ps"
    echo "To view logs: docker-compose logs -f"
}

show_help() {
    echo "Zipsa Demo Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  fly     Deploy to Fly.io (recommended for quick start)"
    echo "  vps     Deploy to any VPS with Docker Compose"
    echo "  help    Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  1. Copy .env.example to .env and fill in your API keys"
    echo "  2. For Fly.io: Install fly CLI (curl -L https://fly.io/install.sh | sh)"
    echo "  3. For VPS: Install Docker and Docker Compose"
}

# Main
case "${1:-help}" in
    fly)
        check_env
        deploy_fly
        ;;
    vps)
        check_env
        deploy_vps
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
