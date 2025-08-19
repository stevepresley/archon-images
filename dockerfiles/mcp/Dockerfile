# Fast single-stage MCP build with security hardening
FROM python:3.11-slim

# Set proper environment defaults for Kubernetes
ENV HOST=0.0.0.0
ENV PORT=8051
ENV ARCHON_MCP_PORT=8051
ENV LOG_LEVEL=INFO
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app:/app/src

WORKDIR /app

# Install system dependencies and clean up in single layer
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy and install requirements from local source
COPY requirements.mcp.txt .
RUN pip install --no-cache-dir -r requirements.mcp.txt

# Copy application code
COPY . .

# Rename mcp directory to mcp_service to avoid module name conflict
RUN mv /app/src/mcp /app/src/mcp_service

# Update import references in the renamed files
RUN sed -i 's/src\.mcp\./src.mcp_service./g' /app/src/mcp_service/mcp_server.py && \
    sed -i 's/src\/mcp\//src\/mcp_service\//g' /app/src/mcp_service/mcp_server.py && \
    find /app/src/mcp_service -name "*.py" -exec sed -i 's/src\.mcp\./src.mcp_service./g' {} \; && \
    find /app/src -name "*.py" -exec sed -i 's/src\.mcp\./src.mcp_service./g' {} \;

# Create non-root user for security (works standalone + Kubernetes can override)
RUN addgroup --gid 1001 archon && \
    adduser --disabled-password --gecos '' --uid 1001 --gid 1001 archon && \
    chown -R archon:archon /app

USER 1001

EXPOSE ${ARCHON_MCP_PORT}

# Note: MCP service may not have a /health endpoint by default
# Health check disabled - use TCP checks in Kubernetes instead

# Run the MCP service
CMD ["python", "/app/src/mcp_service/mcp_server.py"]