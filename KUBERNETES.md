# Kubernetes Deployment Guide for Archon

This guide provides comprehensive instructions for deploying Archon in Kubernetes, addressing common issues and providing best practices.

## 🚨 Critical Configuration Points

### Environment Variables by Service

#### Frontend Container
```yaml
env:
  - name: HOST
    value: "archon.yourdomain.com"  # CRITICAL: Use actual domain, NOT 0.0.0.0
  - name: ARCHON_UI_PORT
    value: "5173"  # Must match Vite default
  - name: PORT
    value: "5173"  # Container port
```

#### Server Container
```yaml
env:
  - name: HOST
    value: "0.0.0.0"  # Bind to all interfaces
  - name: ARCHON_SERVER_PORT
    value: "8181"
  - name: LOG_LEVEL
    value: "INFO"
```

#### Agents Container
```yaml
env:
  - name: HOST
    value: "0.0.0.0"
  - name: ARCHON_AGENTS_PORT
    value: "8052"
  - name: ARCHON_SERVER_HOST
    value: "archon-server"  # Service name for server discovery
  - name: ARCHON_SERVER_PORT
    value: "8181"
  - name: LOG_LEVEL
    value: "INFO"
```

#### MCP Container
```yaml
env:
  - name: HOST
    value: "0.0.0.0"
  - name: ARCHON_MCP_PORT
    value: "8051"
  - name: LOG_LEVEL
    value: "INFO"
```

## 🔧 Port Configuration (CRITICAL)

### Correct Port Mapping
```yaml
# Frontend service - MUST use 5173
ports:
- name: http
  port: 5173      # Service port
  targetPort: 5173 # Container port
  protocol: TCP

# Health check port MUST match
readinessProbe:
  httpGet:
    path: /health
    port: 5173    # Use 5173, NOT 3737
```

### Common Port Mistakes
```yaml
# ❌ WRONG - Causes health check failures
ports:
- port: 3737
  targetPort: 5173

# ✅ CORRECT - Both must be 5173
ports:
- port: 5173
  targetPort: 5173
```

## 🏥 Health Check Configuration

### Frontend Health Checks
```yaml
readinessProbe:
  httpGet:
    path: /health  # Custom health endpoint added to images
    port: 5173
  initialDelaySeconds: 5
  periodSeconds: 30
  timeoutSeconds: 3
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health
    port: 5173
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 3
  failureThreshold: 3
```

### Server Health Checks
```yaml
readinessProbe:
  httpGet:
    path: /health  # Dedicated health endpoint
    port: 8181
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

### Agents Health Checks
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8052
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

### MCP Health Checks
```yaml
# MCP service may not have /health endpoint - disable health checks
# readinessProbe: {}  # Disabled
# livenessProbe: {}   # Disabled
```

## 📝 Complete Kubernetes Manifest Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: archon
  namespace: ai
spec:
  replicas: 1
  selector:
    matchLabels:
      app: archon
  template:
    metadata:
      labels:
        app: archon
    spec:
      containers:
      # Frontend Container
      - name: frontend
        image: ghcr.io/dapperdivers/archon-frontend:latest
        ports:
        - containerPort: 5173
        env:
        - name: HOST
          value: "archon.yourdomain.com"  # Replace with your domain
        - name: ARCHON_UI_PORT
          value: "5173"
        readinessProbe:
          httpGet:
            path: /health.html  # Updated health endpoint
            port: 5173
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 3
        livenessProbe:
          httpGet:
            path: /health.html
            port: 5173
          initialDelaySeconds: 30
          periodSeconds: 30
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          runAsGroup: 1001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false  # Vite dev server needs temp files
          capabilities:
            drop:
            - ALL
          seccompProfile:
            type: RuntimeDefault

      # Server Container  
      - name: server
        image: ghcr.io/dapperdivers/archon-server:latest
        ports:
        - containerPort: 8181
        env:
        - name: HOST
          value: "0.0.0.0"
        - name: ARCHON_SERVER_PORT
          value: "8181"
        - name: LOG_LEVEL
          value: "INFO"
        readinessProbe:
          httpGet:
            path: /health
            port: 8181
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8181
          initialDelaySeconds: 60
          periodSeconds: 30
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          runAsGroup: 1001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true  # Python services can run read-only
          capabilities:
            drop:
            - ALL
          seccompProfile:
            type: RuntimeDefault

      # Agents Container
      - name: agents
        image: ghcr.io/dapperdivers/archon-agents:latest
        ports:
        - containerPort: 8052
        env:
        - name: HOST
          value: "0.0.0.0"
        - name: ARCHON_AGENTS_PORT
          value: "8052"
        - name: LOG_LEVEL
          value: "INFO"
        readinessProbe:
          httpGet:
            path: /health
            port: 8052
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 10
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001

      # MCP Container
      - name: mcp
        image: ghcr.io/dapperdivers/archon-mcp:latest
        ports:
        - containerPort: 8051
        env:
        - name: HOST
          value: "0.0.0.0"
        - name: ARCHON_MCP_PORT
          value: "8051"
        - name: LOG_LEVEL
          value: "INFO"
        # No health checks for MCP
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001

---
apiVersion: v1
kind: Service
metadata:
  name: archon
  namespace: ai
spec:
  selector:
    app: archon
  ports:
  - name: frontend
    port: 5173
    targetPort: 5173
  - name: server
    port: 8181
    targetPort: 8181
  - name: agents
    port: 8052
    targetPort: 8052
  - name: mcp
    port: 8051
    targetPort: 8051

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: archon
  namespace: ai
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - archon.yourdomain.com
    secretName: archon-tls
  rules:
  - host: archon.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: archon
            port:
              number: 5173
```

## 🚨 Common Failure Modes & Solutions

### Issue 1: "Blocked request" Error
**Symptoms:** `curl` connects but returns 403 with "This host is not allowed"
**Cause:** Vite allowed hosts configuration  
**Solution:** Set `HOST=archon.yourdomain.com` (your actual domain) in frontend container

### Issue 2: Health Check Failures
**Symptoms:** Pods stuck at 3/4 or 2/4 ready, health check timeouts
**Cause:** Port mismatches between health checks and actual service ports
**Solution:** Ensure health check ports match container ports (5173 for frontend, not 3737)

### Issue 3: Service Not Ready  
**Symptoms:** Service endpoints show `notReadyAddresses`
**Cause:** Health checks failing, containers not ready
**Solution:** Check container logs and verify health check paths exist

### Issue 4: Frontend Not Loading
**Symptoms:** Blank page or connection refused
**Cause:** Port mapping issues or Vite configuration
**Solution:** Verify frontend uses port 5173 consistently and HOST environment variable is set

## 🧪 Debugging Commands

### Pod Status Check
```bash
kubectl get pods -n ai | grep archon
kubectl describe pod <pod-name> -n ai
```

### Service & Endpoints Verification
```bash
kubectl get svc archon -n ai
kubectl get endpoints archon -n ai
kubectl describe ingress archon -n ai
```

### Container-Level Testing
```bash
# Test frontend health endpoint
kubectl exec <pod> -c frontend -n ai -- wget --spider http://localhost:5173/health

# Check environment variables
kubectl exec <pod> -c frontend -n ai -- env | grep -E "(HOST|ARCHON|VITE)"

# Check logs
kubectl logs <pod> -c frontend -n ai --tail=50
```

### Network Path Testing
```bash
# DNS resolution
nslookup archon.yourdomain.com

# Direct access test
curl -k -v https://archon.yourdomain.com/

# Check for "Blocked request" in response
```

## 🔄 Quick Resolution Commands

### Force Reconciliation (if using Flux/GitOps)
```bash
flux reconcile hr archon -n ai
```

### Restart Deployment
```bash
kubectl rollout restart deployment archon -n ai
```

### Check Current Status
```bash
kubectl get pods,svc,ingress -n ai | grep archon
```

### Test Access
```bash
curl -k -v https://archon.yourdomain.com/health
```

## 📊 Environment Variable Reference

| Service | Variable | Default | Purpose | Notes |
|---------|----------|---------|---------|-------|
| Frontend | `HOST` | `localhost` | Vite allowed hosts | **MUST** be your domain for K8s |
| Frontend | `ARCHON_UI_PORT` | `5173` | Port configuration | Must match container port |
| Server | `HOST` | `localhost` | Bind address | Use `0.0.0.0` for K8s |
| Server | `ARCHON_SERVER_PORT` | `8181` | Server port | |
| Agents | `HOST` | `localhost` | Bind address | Use `0.0.0.0` for K8s |
| Agents | `ARCHON_AGENTS_PORT` | `8052` | Agents port | |
| MCP | `HOST` | `localhost` | Bind address | Use `0.0.0.0` for K8s |
| MCP | `ARCHON_MCP_PORT` | `8051` | MCP port | |
| All | `LOG_LEVEL` | `INFO` | Logging level | `DEBUG`, `INFO`, `WARN`, `ERROR` |

## 🔐 Enhanced Security Features

The enhanced Docker images include multiple layers of security:

### Container Security
- **Distroless base images** for Python services (minimal attack surface)
- **Non-root user** (UID 1001) for all containers  
- **Multi-stage builds** to remove build tools from production images
- **Input validation** in entrypoint scripts with RFC 1123 hostname validation
- **Secure health endpoints** with proper HTTP security headers
- **No package managers** in final distroless images
- **Read-only root filesystem** support ready

### Pod Security Standards
Apply restricted Pod Security Standards:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: archon
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted  
    pod-security.kubernetes.io/warn: restricted
```

### Security Contexts
**Hybrid Security Approach** (Dockerfile creates user, Kubernetes can override):

```yaml
# Frontend Container Security Context
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # Vite dev server needs temp files
  capabilities:
    drop:
    - ALL
  seccompProfile:
    type: RuntimeDefault

# Backend Services (Server, Agents, MCP) Security Context  
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true  # Python services can run read-only
  capabilities:
    drop:
    - ALL
  seccompProfile:
    type: RuntimeDefault
```

**Benefits of Hybrid Security Approach:**
- ✅ **Secure by default** (containers run as non-root even without Kubernetes)
- ✅ **Kubernetes can override** UID/GID when needed for multi-tenancy
- ✅ **Flexible deployment** (works in Docker, Kubernetes, etc.)
- ✅ **Best of both worlds** (standalone security + orchestration flexibility)
- ✅ **Pod Security Standards** compliance ready

### Network Policies
Restrict network traffic with the provided network policy (see `security/pod-security-policy.yaml`):

- Only allow ingress from ingress controller on port 5173
- Allow inter-service communication on required ports
- Restrict egress to DNS, HTTPS, and internal services
- Deny all other traffic by default

### RBAC Configuration
Minimal service account with restricted permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: archon-service-account
  namespace: archon
automountServiceAccountToken: false  # Disable if not needed
```

## 📈 Monitoring & Observability

### Health Check Monitoring
Monitor health check status:
```bash
kubectl get pods -n ai -o wide | grep archon
```

### Log Monitoring
```bash
# Follow logs for all containers
kubectl logs -f deployment/archon -n ai --all-containers=true

# Specific container logs
kubectl logs -f deployment/archon -n ai -c frontend
```

### Resource Usage
```bash
kubectl top pods -n ai | grep archon
```

This guide addresses the specific issues identified in the comprehensive analysis and provides a robust foundation for Kubernetes deployments.