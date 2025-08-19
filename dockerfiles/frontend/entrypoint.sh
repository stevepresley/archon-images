#!/bin/bash
set -euo pipefail  # Enhanced error handling

# Input validation function
validate_hostname() {
    local hostname="$1"
    # Basic hostname validation (simplified for shell compatibility)  
    case "$hostname" in
        *[!a-zA-Z0-9.-]*)
            echo "❌ Invalid hostname format: $hostname" >&2
            return 1
            ;;
    esac
    
    # Check for common injection attempts (simplified for shell compatibility)
    case "$hostname" in
        *\'*|*\"*|*\;*|*\`*|*\$*|*\(*|*\)*) 
            echo "❌ Hostname contains potentially dangerous characters: $hostname" >&2
            return 1
            ;;
    esac
    
    return 0
}

echo "🚀 Starting Archon Frontend with enhanced security..."

# Check if /app is empty due to volume mount overwriting it
if [ ! -f "package.json" ] || [ ! -d "node_modules" ]; then
    echo "⚠️  Detected missing package.json or node_modules - likely due to volume mount"
    echo "🔄 Restoring from backup..."
    
    # Restore from backup if available
    if [ -d "/opt/archon-backup" ]; then
        if [ ! -f "package.json" ] && [ -f "/opt/archon-backup/package.json" ]; then
            cp /opt/archon-backup/package*.json . || echo "❌ Failed to restore package files"
            echo "✅ Restored package files"
        fi
        
        if [ ! -d "node_modules" ] && [ -d "/opt/archon-backup/node_modules" ]; then
            cp -r /opt/archon-backup/node_modules . || echo "❌ Failed to restore node_modules"
            echo "✅ Restored node_modules"
        fi
    fi
    
    # If still missing package.json, try to install from the restored package.json
    if [ ! -f "package.json" ]; then
        echo "❌ No package.json found and no backup available - cannot start"
        exit 1
    fi
    
    # If node_modules is still missing, try to install
    if [ ! -d "node_modules" ]; then
        echo "🔄 Installing dependencies..."
        npm ci || echo "❌ Failed to install dependencies"
    fi
fi

# Configure Vite allowed hosts from HOST environment variable
if [ -n "${HOST:-}" ] && [ "$HOST" != "localhost" ] && [ "$HOST" != "0.0.0.0" ]; then
    echo "🔧 Configuring Vite for custom HOST: $HOST"
    
    # Validate the HOST input
    if ! validate_hostname "$HOST"; then
        echo "❌ Invalid HOST value, using default configuration" >&2
        HOST=""
    else
        # Simple approach: just add allowedHosts to the existing server config
        echo "📝 Adding allowedHosts to vite.config.ts..."
        
        # Create backup
        cp vite.config.ts vite.config.ts.bak 2>/dev/null || true
        
        # Use sed to add allowedHosts right after the port line in server config
        sed -i "/port: 5173,/a\\      allowedHosts: ['localhost', '127.0.0.1', '$HOST']," vite.config.ts
        
        echo "✅ Added allowedHosts for: $HOST"
    fi
else
    echo "ℹ️  Using default Vite configuration (HOST not set or is localhost/0.0.0.0)"
fi

# Ensure health endpoint exists and is secure
echo "🏥 Setting up health endpoint..."
if [ ! -f "public/health.html" ]; then
    mkdir -p public
    cat > public/health.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Health Check</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="X-Content-Type-Options" content="nosniff">
    <meta http-equiv="X-Frame-Options" content="DENY">
</head>
<body>
    <h1>Frontend Service is Healthy</h1>
    <p>Status: OK</p>
</body>
</html>
EOF
fi

echo "🌐 Frontend will be available on port ${VITE_PORT}"
echo "🔒 Security: Non-root user, input validation enabled"

# Execute the original command with proper signal handling
exec "$@"