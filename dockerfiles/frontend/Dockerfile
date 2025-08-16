# Fast single-stage frontend build with security hardening
FROM node:18-alpine

# Install curl for health checks, bash for entrypoint, and set environment
RUN apk add --no-cache curl bash

# Set environment defaults
ENV NODE_ENV=development
ENV HOST=0.0.0.0
ENV PORT=5173
ENV VITE_PORT=5173

WORKDIR /app

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies and clean cache in one layer
RUN npm ci && npm cache clean --force

# Copy source code
COPY . .

# Create a backup of node_modules and package.json in case of volume overwrites
RUN mkdir -p /opt/archon-backup && \
    cp -r node_modules /opt/archon-backup/ && \
    cp package*.json /opt/archon-backup/

# Copy entrypoint script for HOST configuration
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create health endpoint file
RUN mkdir -p public && \
    echo '<!DOCTYPE html><html><head><title>Health</title><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="X-Content-Type-Options" content="nosniff"><meta http-equiv="X-Frame-Options" content="DENY"></head><body><h1>OK</h1><p>Frontend Service is Healthy</p></body></html>' > public/health.html

# Create non-root user for security (works standalone + Kubernetes can override)
RUN addgroup -g 1001 archon && \
    adduser -D -s /bin/sh -u 1001 -G archon archon && \
    chown -R archon:archon /app

USER 1001

EXPOSE ${VITE_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${VITE_PORT}/health.html || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sh", "-c", "npm run dev -- --host 0.0.0.0 --port ${VITE_PORT}"]