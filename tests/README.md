# Testing

This directory contains files for testing the Docker containers locally before deployment.

## Files

- `docker-compose.test.yml` - Docker Compose file for testing all services
- `test-containers.sh` - Shell script to build and test containers locally
- `requirements.agents.txt` - Minimal requirements file for testing agents container

## Usage

To test containers locally with the same build context as CI/CD:

1. **Clone upstream repo** (done in test script):
   ```bash
   cd /tmp && git clone https://github.com/coleam00/Archon.git archon-source
   ```

2. **Copy Dockerfiles** (done in test script):
   ```bash
   cp dockerfiles/*/Dockerfile /tmp/archon-source/[context]/
   cp dockerfiles/frontend/entrypoint.sh /tmp/archon-source/archon-ui-main/
   ```

3. **Build and test**:
   ```bash
   ./tests/test-containers.sh
   ```

4. **Manual testing**:
   ```bash
   # Frontend
   cd /tmp/archon-source/archon-ui-main && docker build -t archon-frontend:test .
   
   # Python services (agents, server, mcp)
   cd /tmp/archon-source/python && docker build -f Dockerfile.agents -t archon-agents:test .
   cd /tmp/archon-source/python && docker build -f Dockerfile.server -t archon-server:test .  
   cd /tmp/archon-source/python && docker build -f Dockerfile.mcp -t archon-mcp:test .
   ```

## Test Results

- ✅ All images build successfully
- ✅ Environment variables work correctly
- ✅ Health endpoints respond (where available)
- ✅ Port configuration is dynamic

## Known Issues

- Frontend entrypoint uses `#!/bin/bash` but Alpine only has `/bin/sh`