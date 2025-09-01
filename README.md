# Archon Docker Images

This repository automatically builds and publishes Docker images for [Archon](https://github.com/coleam00/Archon) to GitHub Container Registry. The images are built from source and stay up-to-date with the latest releases.

## 🐳 Available Images

| Component | Description | Image |
|-----------|-------------|-------|
| **Server** | FastAPI backend server | `ghcr.io/yourusername/archon-server` |
| **MCP** | Model Context Protocol interface | `ghcr.io/yourusername/archon-mcp` |
| **Agents** | AI agent hosting service | `ghcr.io/yourusername/archon-agents` |
| **Frontend** | React + Vite UI | `ghcr.io/yourusername/archon-frontend` |
| **Docs** | Docusaurus documentation site | `ghcr.io/yourusername/archon-docs` |

> Replace `yourusername` with your GitHub username

## 🤖 Automation

### Two-Workflow System

**1. Check for Updates** (`check-updates.yml`)
- **Daily monitoring** at 6 AM UTC for new commits
- **Smart detection** - only triggers builds for new commits
- **Manual forcing** - option to force check/build
- **Automatic triggering** of build workflow when needed

**2. Build and Push Images** (`build-images.yml`) 
- **Production builds** with security features
- **Multi-platform** support (linux/amd64, linux/arm64)
- **Triggered automatically** by check workflow or manually

### Manual Triggers

**Force a check for updates:**
1. Go to **Actions** → **Check for Archon Updates**
2. Click **Run workflow**
3. Check "Force check" if needed
4. Click **Run workflow**

**Build specific ref directly:**
1. Go to **Actions** → **Build and Push Archon Images**  
2. Click **Run workflow**
3. Enter the desired Archon ref (commit, branch, or tag)
4. Click **Run workflow**

## 🏷️ Image Tags

Each image is tagged with:
- `latest` - Latest built version  
- `{commit-sha}` - Specific Archon commit
- `{date}` - Build date (YYYY-MM-DD)
- `{date}-{short-sha}` - Date with commit identifier

Example:
```bash
# Pull latest
docker pull ghcr.io/yourusername/archon-server:latest

# Pull specific commit
docker pull ghcr.io/yourusername/archon-server:abc1234567890def...

# Pull by date
docker pull ghcr.io/yourusername/archon-server:2024-01-15

# Pull by date with commit
docker pull ghcr.io/yourusername/archon-server:2024-01-15-abc1234
```

## 🚀 Usage

> **For Kubernetes deployments:** See [KUBERNETES.md](KUBERNETES.md) for comprehensive deployment guide addressing common issues like "Blocked request" errors, health check failures, and port configuration problems.

### Quick Start with Docker Compose

```yaml
version: '3.8'
services:
  archon-server:
    image: ghcr.io/yourusername/archon-server:latest
    ports:
      - "8181:8181"
    environment:
      - DATABASE_URL=your_database_url
      
  archon-mcp:
    image: ghcr.io/yourusername/archon-mcp:latest
    ports:
      - "8051:8051"
      
  archon-agents:
    image: ghcr.io/yourusername/archon-agents:latest
    ports:
      - "8052:8052"
      
  archon-frontend:
    image: ghcr.io/yourusername/archon-frontend:latest
    ports:
      - "5173:5173"  # FIXED: Use 5173:5173, not 3737:5173
      
  archon-docs:
    image: ghcr.io/yourusername/archon-docs:latest
    ports:
      - "3838:80"
    environment:
      - ARCHON_DOCS_PORT=3838
```

### Individual Services

```bash
# Run server
docker run -p 8181:8181 ghcr.io/yourusername/archon-server:latest

# Run MCP service
docker run -p 8051:8051 ghcr.io/yourusername/archon-mcp:latest

# Run agents service
docker run -p 8052:8052 ghcr.io/yourusername/archon-agents:latest

# Run frontend - FIXED: Use consistent port mapping
docker run -p 5173:5173 ghcr.io/yourusername/archon-frontend:latest

# Run docs service
docker run -p 3838:80 -e ARCHON_DOCS_PORT=3838 ghcr.io/yourusername/archon-docs:latest
```

## ⚙️ Setup

### 1. Fork this Repository
Fork this repository to your GitHub account.

### 2. Enable GitHub Actions
Ensure GitHub Actions are enabled in your repository settings.

### 3. Configure Container Registry
The workflow uses GitHub Container Registry (GHCR) by default. No additional setup is required - it uses the built-in `GITHUB_TOKEN`.

### 4. First Run
Manually trigger the workflow to build your first set of images:
1. Go to **Actions** tab
2. Select **Build and Push Archon Images**
3. Click **Run workflow**
4. Leave the ref as `main` (or specify a version)
5. Click **Run workflow**

## 📋 Workflow Details

### Source Repository
- **Upstream**: `coleam00/Archon`
- **Method**: Builds from source (not copying existing images)
- **Components**: All 5 microservices

### Build Matrix
The build workflow processes all components in parallel with enhanced Kubernetes support:
- **Server**: Python FastAPI backend with health endpoint and proper environment defaults
- **MCP**: Model Context Protocol service with non-root user security
- **Agents**: AI agent hosting with health checks and logging configuration
- **Frontend**: React + Vite application with HOST variable support and health endpoint
- **Docs**: Docusaurus documentation site served with nginx and non-root security

### Workflow Separation Benefits
- **Cleaner logs** - check and build operations are separate
- **Faster feedback** - know immediately if new commits exist
- **Flexible triggering** - build specific refs without checking
- **Better monitoring** - separate success/failure tracking
- **Resource efficiency** - only build when needed

### Smart Caching
- **GitHub Actions cache** for faster subsequent builds
- **Duplicate detection** - check workflow prevents unnecessary builds
- **Multi-platform builds** cached separately

## ✨ Kubernetes Enhancements

This repository includes specialized Docker images with Kubernetes-specific improvements:

### Frontend Enhancements
- **HOST Variable Support**: Automatically configures Vite allowed hosts for custom domains
- **Health Endpoint**: Dedicated `/health` endpoint for proper health checks
- **Port Consistency**: Uses port 5173 throughout (no more 3737:5173 confusion)
- **Non-root Security**: Runs as user 1001 for enhanced security

### Backend Services
- **Health Endpoints**: All services include `/health` endpoints where applicable
- **Environment Defaults**: Proper `HOST=0.0.0.0` defaults for Kubernetes
- **Security Context**: Non-root users (UID 1001) for all containers
- **Logging**: Configurable `LOG_LEVEL` environment variable

### Common Issues Resolved
- ✅ **"Blocked request" errors** - Fixed with proper HOST configuration
- ✅ **Health check failures** - Dedicated health endpoints and correct port mapping
- ✅ **Port confusion** - Consistent 5173 port usage for frontend
- ✅ **Security vulnerabilities** - Non-root containers with proper user contexts

See [KUBERNETES.md](KUBERNETES.md) for complete deployment guide and troubleshooting.

## 🔒 Security & Production Features

### Container Security
- **🔐 Container Signing**: All images signed with [cosign](https://docs.sigstore.dev/cosign/overview/) using keyless signing
- **📋 SBOM Generation**: Software Bill of Materials included with each image
- **🛡️ Build Attestation**: Cryptographic attestation of build provenance  
- **🔍 Vulnerability Scanning**: Trivy security scanning with results in GitHub Security tab
- **🏗️ Multi-platform**: Native support for AMD64 and ARM64 architectures

### Image Metadata
Rich OCI-compliant metadata including:
- Source repository and commit information
- Build timestamps and versioning
- License information (MIT)
- Component descriptions and documentation links

### Supply Chain Security
- **Reproducible builds** from source code
- **Attestation artifacts** stored in registry
- **Signed provenance** linking images to source commits
- **Security scanning** results available in GitHub Security tab

### Verification

Verify image signatures:
```bash
# Install cosign
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# Verify image signature
cosign verify ghcr.io/dapperdivers/archon-server:latest \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

Check SBOM:
```bash
# Download and view SBOM
cosign download sbom ghcr.io/dapperdivers/archon-server:latest
```

View attestations:
```bash
# Download attestation
cosign download attestation ghcr.io/dapperdivers/archon-server:latest
```

## 🔧 Customization

### Change Source Repository
Edit the `UPSTREAM_REPO` environment variable in `.github/workflows/build-images.yml`:

```yaml
env:
  REGISTRY: ghcr.io
  UPSTREAM_REPO: your-fork/Archon  # Change this
```

### Change Schedule
Modify the cron schedule in the workflow:

```yaml
schedule:
  # Currently: daily at 6 AM UTC
  - cron: '0 6 * * *'
  # Example: twice daily
  - cron: '0 6,18 * * *'
```

### Add Custom Tags
Extend the metadata section to add custom tags:

```yaml
tags: |
  type=raw,value=latest
  type=raw,value=${{ needs.check-releases.outputs.target_ref }}
  type=raw,value={{date 'YYYY-MM-DD'}}
  type=raw,value=custom-tag  # Add your custom tags
```

## 📦 Registry

Images are published to **GitHub Container Registry** (`ghcr.io`) under your account. They will be:
- **Public** by default (can be changed in package settings)
- **Linked** to this repository
- **Versioned** with multiple tags

## 🛡️ Security

- **Keyless signing** with GitHub OIDC (no manual keys required)
- **SLSA Level 3** build provenance attestation
- **Vulnerability scanning** integrated into CI/CD
- **Multi-platform builds** ensure compatibility
- **Reproducible builds** from source code
- **Supply chain security** with SBOM and attestations
- **GitHub Security tab** integration for vulnerability reports

## 📈 Monitoring

Check the **Actions** tab to monitor:
- Build status and logs
- Failed builds and errors
- Build duration and cache performance
- Image publishing status
- Security scan results and attestation generation

### Security Monitoring
- **Security** tab shows vulnerability scan results
- **Packages** tab shows published images with signatures
- **Attestations** are available for each image version

## 🧪 Testing

For testing containers locally before deployment, see the [tests/](tests/) directory which includes:

- `test-containers.sh` - Script to build and test all containers locally
- `docker-compose.test.yml` - Docker Compose configuration for testing
- `README.md` - Testing documentation and usage instructions

The testing setup replicates the same build process used in CI/CD.

## 🤝 Contributing

This repository is focused solely on Docker image automation. For Archon-related issues or contributions, please visit the [upstream repository](https://github.com/coleam00/Archon).