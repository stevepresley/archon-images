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
UPSTREAM_REPO="https://github.com/coleam00/Archon.git"
ARCHON_REF="${1:-main}"  # Use provided ref or default to main
SOURCE_DIR="/tmp/archon-source"

print_status "Setting up test environment for Archon..."
print_status "Repository: $UPSTREAM_REPO"
print_status "Reference: $ARCHON_REF"
print_status "Target directory: $SOURCE_DIR"

# Clean up existing source if it exists
if [ -d "$SOURCE_DIR" ]; then
    print_status "Removing existing source directory..."
    rm -rf "$SOURCE_DIR"
fi

# Clone the Archon repository
print_status "Cloning Archon repository..."
if git clone --branch "$ARCHON_REF" --depth 1 "$UPSTREAM_REPO" "$SOURCE_DIR"; then
    print_success "Successfully cloned Archon repository"
else
    print_error "Failed to clone Archon repository"
    exit 1
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

print_success "Test environment setup complete!"
print_status "You can now run: ./test-containers.sh"