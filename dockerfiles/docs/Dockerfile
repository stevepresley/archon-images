# Docs Service - Docusaurus documentation site with nginx serving
ARG BUILD_VERSION="2025-09-01T13:15:00Z-initial-docs"

# Build stage - Node.js for Docusaurus
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy source files and build documentation
COPY . .
RUN npm run build

# Runtime stage - nginx for serving static files
FROM nginx:alpine

# Re-declare ARG for runtime stage  
ARG BUILD_VERSION="2025-09-01T13:15:00Z-initial-docs"

# Copy built documentation from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Create non-root user for security
RUN addgroup -g 1001 archon && \
    adduser -D -u 1001 -G archon archon && \
    chown -R archon:archon /usr/share/nginx/html && \
    chown -R archon:archon /var/cache/nginx && \
    chown -R archon:archon /var/log/nginx && \
    chown -R archon:archon /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown archon:archon /var/run/nginx.pid

# Switch to non-root user
USER 1001

# Set environment defaults for Kubernetes
ENV HOST=0.0.0.0
ENV PORT=80
ENV ARCHON_DOCS_PORT=3838
ENV BUILD_VERSION_CHECK="echo 'BUILD VERSION: ${BUILD_VERSION}'"

# Expose port
EXPOSE ${PORT}

# Health check for documentation availability
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Run nginx in foreground (JSON array format for better signal handling)
CMD ["nginx", "-g", "daemon off;"]