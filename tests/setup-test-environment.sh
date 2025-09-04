#!/bin/bash
# Setup script to download Archon source for local testing
# This replicates what GitHub Actions does but for local testing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[SETUP]${NC} $1"
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

# Configuration
UPSTREAM_REPO="https://github.com/stevepresley/archon_beta.git"
ARCHON_REF="${1:-main}"  # Use provided ref or default to main
SOURCE_DIR="/tmp/archon-source"

print_status "Setting up test environment for Archon..."
print_status "Repository: $UPSTREAM_REPO"
print_status "Reference: $ARCHON_REF"
print_status "Target directory: $SOURCE_DIR"

# Only clone if source directory doesn't exist
if [ ! -d "$SOURCE_DIR" ]; then
    print_status "Cloning Archon repository..."
    if git clone --branch "$ARCHON_REF" --depth 1 "$UPSTREAM_REPO" "$SOURCE_DIR"; then
        print_success "Successfully cloned Archon repository"
    else
        print_error "Failed to clone Archon repository"
        exit 1
    fi
else
    print_status "Using existing source directory..."
fi

# Verify expected directories exist
print_status "Verifying source structure..."
required_dirs=("$SOURCE_DIR/python" "$SOURCE_DIR/archon-ui-main")
missing_dirs=()

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -eq 0 ]; then
    print_success "All required directories found"
else
    print_error "Missing required directories:"
    for dir in "${missing_dirs[@]}"; do
        echo "  - $dir"
    done
    exit 1
fi

# Show directory structure
print_status "Source directory structure:"
ls -la "$SOURCE_DIR"

print_status "Python directory contents:"
ls -la "$SOURCE_DIR/python" | head -10

print_status "Frontend directory contents:"
ls -la "$SOURCE_DIR/archon-ui-main" | head -10

# Copy custom Dockerfiles to build contexts (matching GitHub workflow exactly)
print_status "Copying custom Dockerfiles to build contexts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Copy our enhanced Dockerfile to the appropriate location (exactly like GitHub)
cp "$PROJECT_ROOT/dockerfiles/server/Dockerfile" "$SOURCE_DIR/python/Dockerfile.server"
cp "$PROJECT_ROOT/dockerfiles/agents/Dockerfile" "$SOURCE_DIR/python/Dockerfile.agents"  
cp "$PROJECT_ROOT/dockerfiles/mcp/Dockerfile" "$SOURCE_DIR/python/Dockerfile.mcp"
cp "$PROJECT_ROOT/dockerfiles/frontend/Dockerfile" "$SOURCE_DIR/archon-ui-main/Dockerfile"
print_success "Copied all custom Dockerfiles to build contexts"

# Copy frontend entrypoint script (exactly like GitHub)
cp "$PROJECT_ROOT/dockerfiles/frontend/entrypoint.sh" "$SOURCE_DIR/archon-ui-main/entrypoint.sh"
chmod +x "$SOURCE_DIR/archon-ui-main/entrypoint.sh"
print_success "Copied frontend entrypoint.sh"

# Copy docs Dockerfile if docs directory exists
if [ -d "$SOURCE_DIR/docs" ]; then
    cp "$PROJECT_ROOT/dockerfiles/docs/Dockerfile" "$SOURCE_DIR/docs/Dockerfile"
    # Fix logo file extension mismatch (docs expect .png but file is .svg)
    if [ -f "$SOURCE_DIR/docs/static/img/logo-neon.svg" ]; then
        cp "$SOURCE_DIR/docs/static/img/logo-neon.svg" "$SOURCE_DIR/docs/static/img/logo-neon.png"
        print_success "Fixed logo-neon.png file extension issue"
    fi
    print_success "Copied docs Dockerfile"
else
    print_warning "Docs directory not found - skipping docs Dockerfile"
fi

print_success "Test environment setup complete!"
print_status "You can now run: ./test-containers.sh"