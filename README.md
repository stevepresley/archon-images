# Archon Docker Images

This repository automatically builds and publishes Docker images for [Archon](https://github.com/coleam00/Archon) to GitHub Container Registry. The images are built from source and stay up-to-date with the latest releases.

## 🐳 Available Images

| Component | Description | Image |
|-----------|-------------|-------|
| **Server** | FastAPI backend server | `ghcr.io/yourusername/archon-server` |
| **MCP** | Model Context Protocol interface | `ghcr.io/yourusername/archon-mcp` |
| **Agents** | AI agent hosting service | `ghcr.io/yourusername/archon-agents` |
| **Frontend** | React + Vite UI | `ghcr.io/yourusername/archon-frontend` |

> Replace `yourusername` with your GitHub username

## 🤖 Automation

### Automatic Updates
- **Daily checks** at 6 AM UTC for new Archon releases
- **Smart rebuilding** - only builds if a new version is detected
- **Multi-platform** support (linux/amd64, linux/arm64)
- **Efficient caching** to speed up builds

### Manual Triggers
You can manually trigger builds for any ref (tag, branch, or commit):

1. Go to **Actions** → **Build and Push Archon Images**
2. Click **Run workflow**
3. Enter the desired Archon ref (defaults to `main`)
4. Click **Run workflow**

## 🏷️ Image Tags

Each image is tagged with:
- `latest` - Latest built version
- `{version}` - Specific Archon version/ref
- `{date}` - Build date (YYYY-MM-DD)

Example:
```bash
# Pull latest
docker pull ghcr.io/yourusername/archon-server:latest

# Pull specific version
docker pull ghcr.io/yourusername/archon-server:v1.2.3

# Pull by date
docker pull ghcr.io/yourusername/archon-server:2024-01-15
```

## 🚀 Usage

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
      - "3737:3737"
```

### Individual Services

```bash
# Run server
docker run -p 8181:8181 ghcr.io/yourusername/archon-server:latest

# Run MCP service
docker run -p 8051:8051 ghcr.io/yourusername/archon-mcp:latest

# Run agents service
docker run -p 8052:8052 ghcr.io/yourusername/archon-agents:latest

# Run frontend
docker run -p 3737:3737 ghcr.io/yourusername/archon-frontend:latest
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
- **Components**: All 4 microservices

### Build Matrix
The workflow builds all components in parallel:
- **Server**: Python FastAPI backend
- **MCP**: Model Context Protocol service
- **Agents**: AI agent hosting
- **Frontend**: React + Vite application

### Smart Caching
- **GitHub Actions cache** for faster subsequent builds
- **Duplicate detection** - skips building if image already exists
- **Multi-platform builds** cached separately

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

- Uses GitHub's built-in `GITHUB_TOKEN` (no manual token setup required)
- Builds from source (no pre-built image dependencies)
- Multi-platform builds ensure compatibility
- All builds are reproducible and auditable

## 📈 Monitoring

Check the **Actions** tab to monitor:
- Build status and logs
- Failed builds and errors
- Build duration and cache performance
- Image publishing status

## 🤝 Contributing

This repository is focused solely on Docker image automation. For Archon-related issues or contributions, please visit the [upstream repository](https://github.com/coleam00/Archon).