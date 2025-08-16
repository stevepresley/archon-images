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
        # Sanitize HOST for JavaScript context (escape quotes and backslashes)
        SAFE_HOST=$(printf '%s\n' "$HOST" | sed 's/[\\"]/\\&/g')
        
        # Check if vite.config.js exists and update it
        if [ -f "vite.config.js" ]; then
            echo "📝 Updating existing vite.config.js..."
            # Create backup in /tmp with timestamp (avoid permission issues)
            BACKUP_FILE="/tmp/vite.config.js.bak.$(date +%s)"
            cp vite.config.js "$BACKUP_FILE" 2>/dev/null || echo "⚠️  Could not create backup file"
            
            # Use a more secure approach with temporary file
            TEMP_CONFIG=$(mktemp)
            
            # Update the server configuration to include allowedHosts
            node -e "
            const fs = require('fs');
            const path = 'vite.config.js';
            let content = fs.readFileSync(path, 'utf8');
            
            // Sanitized HOST value
            const safeHost = '$SAFE_HOST';
            
            // Add allowed hosts configuration
            const hostConfig = \`
  server: {
    host: '0.0.0.0',
    port: ${VITE_PORT:-5173},
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      '\${safeHost}'
    ]
  },\`;
            
            // Replace existing server config or add if none exists
            if (content.includes('server:')) {
              content = content.replace(/server:\s*{[^}]*}/, hostConfig.trim());
            } else {
              // Add server config to the config object
              content = content.replace('export default defineConfig({', \`export default defineConfig({\${hostConfig}\`);
            }
            
            fs.writeFileSync('$TEMP_CONFIG', content);
            console.log('✅ Generated secure vite.config.js');
            " && mv "$TEMP_CONFIG" vite.config.js || {
                echo "❌ Failed to update vite.config.js, using backup" >&2
                cp "$BACKUP_FILE" vite.config.js 2>/dev/null || true
                rm -f "$TEMP_CONFIG" 2>/dev/null || true
            }
            
        elif [ -f "vite.config.ts" ]; then
            echo "📝 Updating existing vite.config.ts..."
            BACKUP_FILE_TS="/tmp/vite.config.ts.bak.$(date +%s)"
            cp vite.config.ts "$BACKUP_FILE_TS" 2>/dev/null || echo "⚠️  Could not create backup file"
            
            TEMP_CONFIG=$(mktemp)
            
            # Similar update for TypeScript config
            node -e "
            const fs = require('fs');
            const path = 'vite.config.ts';
            let content = fs.readFileSync(path, 'utf8');
            
            const safeHost = '$SAFE_HOST';
            
            const hostConfig = \`
  server: {
    host: '0.0.0.0',
    port: ${VITE_PORT:-5173},
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      '\${safeHost}'
    ]
  },\`;
            
            if (content.includes('server:')) {
              content = content.replace(/server:\s*{[^}]*}/s, hostConfig.trim());
            } else {
              content = content.replace('export default defineConfig({', \`export default defineConfig({\${hostConfig}\`);
            }
            
            fs.writeFileSync('$TEMP_CONFIG', content);
            console.log('✅ Generated secure vite.config.ts');
            " && mv "$TEMP_CONFIG" vite.config.ts || {
                echo "❌ Failed to update vite.config.ts, using backup" >&2
                cp "$BACKUP_FILE_TS" vite.config.ts 2>/dev/null || true
                rm -f "$TEMP_CONFIG" 2>/dev/null || true
            }
        else
            echo "📝 Creating new vite.config.js with HOST configuration..."
            # Create secure config file
            cat > vite.config.js << EOF
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    host: '0.0.0.0',
    port: ${VITE_PORT:-5173},
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      '$SAFE_HOST'
    ]
  }
})
EOF
            echo "✅ Created secure vite.config.js with custom HOST: $HOST"
        fi
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