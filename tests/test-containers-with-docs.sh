#!/bin/bash
# Test script for Archon Docker containers
# This script replicates the CI/CD build process locally
set -euo pipefail

# Parse command line arguments
REBUILD_ALL=false
REBUILD_SERVICES=""
SKIP_SERVICES=""
LOG_FILE=""
NO_CLEANUP=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --rebuild-all)
      REBUILD_ALL=true
      shift
      ;;
    --rebuild)
      REBUILD_SERVICES="$2"
      shift 2
      ;;
    --skip)
      SKIP_SERVICES="$2" 
      shift 2
      ;;
    --log)
      if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
        LOG_FILE="$2"
        shift 2
      else
        LOG_FILE="logs/test_containers_with_docs.log"
        shift
      fi
      ;;
    --no-cleanup)
      NO_CLEANUP=true
      shift
      ;;
    *)
      echo "Usage: $0 [--rebuild-all] [--rebuild service1,service2] [--skip service1,service2] [--log logfile] [--no-cleanup]"
      echo "Services: frontend, agents, archon-server, mcp, docs"
      exit 1
      ;;
  esac
done

# Setup logging if requested
if [ -n "$LOG_FILE" ]; then
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    # Redirect all output to both console and log file
    exec > >(tee "$LOG_FILE") 2>&1
fi

echo "🧪 Testing Archon Docker containers locally..."
echo "📅 Test started at: $(date)"
echo "⚙️  Command line args: $0 $*"
if [ "$REBUILD_ALL" = true ]; then
    echo "🔄 Mode: Rebuild all services"
elif [ -n "$REBUILD_SERVICES" ]; then
    echo "🔄 Mode: Rebuild specific services: $REBUILD_SERVICES"
fi
if [ -n "$SKIP_SERVICES" ]; then
    echo "⏭️  Skipping services: $SKIP_SERVICES"
fi
if [ "$NO_CLEANUP" = true ]; then
    echo "🚫 Cleanup disabled - containers will remain running"
fi

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
    if [ "$NO_CLEANUP" = true ]; then
        print_status "Cleanup disabled - leaving containers running"
        print_status "To stop containers manually, run:"
        print_status "  docker compose -f $SCRIPT_DIR/docker-compose.test-with-docs.yml down"
        return
    fi
    print_status "Cleaning up containers and networks..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    docker compose -f "$SCRIPT_DIR/docker-compose.test-with-docs.yml" down --remove-orphans 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Check if source directory and docs setup exists, if not run setup
SOURCE_DIR="/tmp/archon-source"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if we need to run setup (missing source or any outdated dockerfiles)
# Also force setup if docs is being rebuilt (to ensure logo fix is applied)
FORCE_SETUP_FOR_DOCS=false
if [[ "$REBUILD_ALL" = true ]] || [[ "$REBUILD_SERVICES" == *"docs"* ]]; then
    FORCE_SETUP_FOR_DOCS=true
fi

if [ ! -d "$SOURCE_DIR" ] || \
   [ ! -d "$SOURCE_DIR/docs" ] || \
   [ "$FORCE_SETUP_FOR_DOCS" = true ] || \
   ! cmp -s "$PROJECT_ROOT/dockerfiles/server/Dockerfile" "$SOURCE_DIR/python/Dockerfile.server" 2>/dev/null || \
   ! cmp -s "$PROJECT_ROOT/dockerfiles/agents/Dockerfile" "$SOURCE_DIR/python/Dockerfile.agents" 2>/dev/null || \
   ! cmp -s "$PROJECT_ROOT/dockerfiles/mcp/Dockerfile" "$SOURCE_DIR/python/Dockerfile.mcp" 2>/dev/null || \
   ! cmp -s "$PROJECT_ROOT/dockerfiles/frontend/Dockerfile" "$SOURCE_DIR/archon-ui-main/Dockerfile" 2>/dev/null || \
   [ ! -f "$SOURCE_DIR/archon-ui-main/entrypoint.sh" ] || \
   ! cmp -s "$PROJECT_ROOT/dockerfiles/docs/Dockerfile" "$SOURCE_DIR/docs/Dockerfile" 2>/dev/null; then
    if [ "$FORCE_SETUP_FOR_DOCS" = true ]; then
        print_status "Docs rebuild requested - forcing setup to apply logo fix..."
    else
        print_status "Source directory or docs setup missing/outdated. Running setup first..."
    fi
    if [ -f "$SCRIPT_DIR/setup-test-environment.sh" ]; then
        "$SCRIPT_DIR/setup-test-environment.sh"
    else
        print_error "Setup script not found. Please run setup-test-environment.sh first"
        exit 1
    fi
fi

# Build images based on flags
print_status "Building Docker images..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_CMD="docker compose -f $SCRIPT_DIR/docker-compose.test-with-docs.yml build"

if [ "$REBUILD_ALL" = true ]; then
    BUILD_CMD="$BUILD_CMD --no-cache"
elif [ -n "$REBUILD_SERVICES" ]; then
    BUILD_CMD="$BUILD_CMD --no-cache $REBUILD_SERVICES"
fi

if [ -n "$SKIP_SERVICES" ]; then
    # Remove skipped services from docker-compose temporarily
    print_status "Skipping services: $SKIP_SERVICES"
    for service in ${SKIP_SERVICES//,/ }; do
        BUILD_CMD=$(echo "$BUILD_CMD" | sed "s/$service//g")
    done
fi

eval $BUILD_CMD

if [ $? -eq 0 ]; then
    print_success "All images built successfully"
else
    print_error "Failed to build images"
    exit 1
fi

# Start containers
print_status "Starting containers..."
docker compose -f "$SCRIPT_DIR/docker-compose.test-with-docs.yml" up -d

# Wait for containers to start
print_status "Waiting for containers to start (30 seconds)..."
sleep 30

# Check container status
print_status "Checking container status..."
docker compose -f "$SCRIPT_DIR/docker-compose.test-with-docs.yml" ps

# Test each service
test_service() {
    local service=$1
    local port=$2
    local endpoint=$3
    
    print_status "Testing $service on port $port..."
    
    # Check if container is running
    if ! docker compose -f "$SCRIPT_DIR/docker-compose.test-with-docs.yml" ps $service | grep -q "Up"; then
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
    docker compose -f "$SCRIPT_DIR/docker-compose.test-with-docs.yml" logs --tail=10 $service
}

# Test all services
test_service "frontend" "5173" "/health.html"
test_service "agents" "8052" "/health"
test_service "archon-server" "8181" "/health"
test_service "mcp" "8051" ""
test_service "docs" "3838" "/"

# Show overall health
print_status "Health check status:"
docker compose -f "$SCRIPT_DIR/docker-compose.test-with-docs.yml" ps

# Check for any error logs
print_status "Checking for error logs..."
error_count=0
for service in frontend agents archon-server mcp docs; do
    if docker compose -f "$SCRIPT_DIR/docker-compose.test-with-docs.yml" logs $service | grep -i "error\|exception\|failed" | grep -v "test"; then
        print_error "Found errors in $service logs"
        ((error_count++))
    fi
done

if [ $error_count -eq 0 ]; then
    print_success "No critical errors found in logs"
else
    print_warning "Found $error_count services with errors"
fi

if [ "$NO_CLEANUP" = true ]; then
    print_status "Test complete. Containers are still running for manual testing:"
    print_status "  📚 Docs: http://localhost:3838"
    print_status "  🖥️  Frontend: http://localhost:5173" 
    print_status "  🤖 Agents: http://localhost:8052"
    print_status "  🏛️  Server: http://localhost:8181"
    print_status "  🔌 MCP: http://localhost:8051"
    print_status ""
    print_status "To stop containers when done:"
    print_status "  docker compose -f $SCRIPT_DIR/docker-compose.test-with-docs.yml down"
else
    print_status "Test complete. Containers will be cleaned up automatically."
    print_status "If you want to keep containers running, press Ctrl+C now and run:"
    print_status "  docker compose -f $SCRIPT_DIR/docker-compose.test-with-docs.yml down"
    
    # Keep running for a bit to allow manual inspection
    sleep 10
fi