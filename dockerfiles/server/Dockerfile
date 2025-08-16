# Fast single-stage server build with security hardening
FROM python:3.11-slim

# Set proper environment defaults for Kubernetes  
ENV HOST=0.0.0.0
ENV PORT=8181
ENV ARCHON_SERVER_PORT=8181
ENV LOG_LEVEL=INFO
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app:/app/src:/root/.local/lib/python3.11/site-packages

WORKDIR /app

# Fetch latest requirements from upstream and install Python dependencies
RUN curl -o requirements.txt https://raw.githubusercontent.com/coleam00/Archon/main/python/requirements.server.txt \
    && pip install --user --no-cache-dir -r requirements.txt \
    && rm requirements.txt

# Install runtime dependencies for Playwright (minimal set)
RUN apt-get update && apt-get install -y \
    wget \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*



# Copy application code
COPY . .

# Install Playwright browsers as root first (system-wide installation)
RUN python -m playwright install chromium

# Create non-root user and set ownership
RUN addgroup --gid 1001 archon && \
    adduser --disabled-password --gecos '' --uid 1001 --gid 1001 archon && \
    chown -R archon:archon /app

# Switch to non-root user
USER 1001
ENV HOME=/home/archon

EXPOSE ${ARCHON_SERVER_PORT}

# Health check using Python (faster than curl for our use case)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request, os; urllib.request.urlopen(f'http://localhost:{os.environ[\"ARCHON_SERVER_PORT\"]}/health').read()" || exit 1

# Run the server with configurable port (matching original Archon structure)
CMD sh -c "python -m uvicorn src.server.main:socket_app --host 0.0.0.0 --port ${ARCHON_SERVER_PORT} --workers 1"