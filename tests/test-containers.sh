#!/bin/bash
# Test script for Archon Docker containers
# This script replicates the CI/CD build process locally
set -euo pipefail

echo "🧪 Testing Archon Docker containers locally..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up containers and networks..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" down --remove-orphans 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Check if source directory exists, if not run setup
SOURCE_DIR="/tmp/archon-source"
if [ ! -d "$SOURCE_DIR" ]; then
    print_status "Source directory not found. Running setup first..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/setup-test-environment.sh" ]; then
        "$SCRIPT_DIR/setup-test-environment.sh"
    else
        print_error "Setup script not found. Please run setup-test-environment.sh first"
        exit 1
    fi
fi

# Build all images
print_status "Building Docker images..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" build --no-cache

if [ $? -eq 0 ]; then
    print_success "All images built successfully"
else
    print_error "Failed to build images"
    exit 1
fi

# Start containers
print_status "Starting containers..."
docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" up -d

# Wait for containers to start
print_status "Waiting for containers to start (30 seconds)..."
sleep 30

# Check container status
print_status "Checking container status..."
docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" ps

# Test each service
test_service() {
    local service=$1
    local port=$2
    local endpoint=$3
    
    print_status "Testing $service on port $port..."
    
    # Check if container is running
    if ! docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" ps $service | grep -q "Up"; then
        print_error "$service container is not running"
        return 1
    fi
    
    # Test endpoint if provided
    if [ -n "$endpoint" ]; then
        if curl -f -s "http://localhost:$port$endpoint" > /dev/null; then
            print_success "$service is responding on port $port"
        else
            print_warning "$service is not responding on endpoint $endpoint (may not have health endpoint)"
        fi
    else
        print_warning "$service started but no endpoint to test"
    fi
    
    # Show recent logs
    print_status "Recent logs for $service:"
    docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs --tail=10 $service
}

# Test all services
test_service "frontend" "5173" "/health.html"
test_service "agents" "8052" "/health"
test_service "server" "8181" "/health"
test_service "mcp" "8051" ""
test_service "docs" "3838" "/"

# Show overall health
print_status "Health check status:"
docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" ps

# Check for any error logs
print_status "Checking for error logs..."
error_count=0
for service in frontend agents server mcp docs; do
    if docker compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs $service | grep -i "error\|exception\|failed" | grep -v "test"; then
        print_error "Found errors in $service logs"
        ((error_count++))
    fi
done

if [ $error_count -eq 0 ]; then
    print_success "No critical errors found in logs"
else
    print_warning "Found $error_count services with errors"
fi

print_status "Test complete. Containers will be cleaned up automatically."
print_status "If you want to keep containers running, press Ctrl+C now and run:"
print_status "  docker compose -f $SCRIPT_DIR/docker-compose.test.yml down"

# Keep running for a bit to allow manual inspection
sleep 10