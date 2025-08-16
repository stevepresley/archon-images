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

# Fetch latest requirements from upstream and install Python dependencies
RUN curl -o requirements.txt https://raw.githubusercontent.com/coleam00/Archon/main/python/requirements.mcp.txt \
    && pip install --no-cache-dir -r requirements.txt \
    && rm requirements.txt

# Override MCP version to match pyproject.toml (fixes import error)
RUN pip install --no-cache-dir --force-reinstall mcp==1.7.1

# Copy application code
COPY . .

# Create non-root user for security (works standalone + Kubernetes can override)
RUN addgroup --gid 1001 archon && \
    adduser --disabled-password --gecos '' --uid 1001 --gid 1001 archon && \
    chown -R archon:archon /app

USER 1001

EXPOSE ${ARCHON_MCP_PORT}

# Note: MCP service may not have a /health endpoint by default
# Health check disabled - use TCP checks in Kubernetes instead

# Run the MCP service
CMD ["python", "/app/src/mcp/mcp_server.py"]