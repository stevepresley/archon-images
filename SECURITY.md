# Security Guide for Archon Docker Images

This guide outlines the comprehensive security measures implemented in the Archon Docker images and deployment configurations.

## 🛡️ Multi-Layer Security Approach

### 1. Supply Chain Security

#### Build-Time Security
- **Signed commits**: All builds are from verified commits
- **Multi-platform builds**: Native ARM64 and AMD64 support  
- **Provenance attestation**: SLSA Level 3 build attestation
- **Container signing**: Images signed with cosign using keyless signing
- **SBOM generation**: Software Bill of Materials for all images
- **Enhanced vulnerability scanning**: Trivy with CRITICAL, HIGH, MEDIUM severity detection
- **Configuration scanning**: Container security benchmarks
- **Build fails on vulnerabilities**: CI pipeline fails on security issues

#### Source Code Security
- **Dependency scanning**: Automated scanning of Python/Node.js dependencies
- **License compliance**: Automated license detection and compliance checking
- **Code quality gates**: Security-focused linting and validation

### 2. Container Security

#### Base Image Selection
```dockerfile
# Python services use distroless for minimal attack surface
FROM gcr.io/distroless/python3-debian11:latest

# Frontend uses minimal Node.js Alpine with security patches
FROM node:18-alpine
```

#### Security Features
- **Distroless images**: Python services run on distroless base images
- **No package managers**: Final images contain no apt, yum, or package managers
- **Multi-stage builds**: Build tools removed from production images
- **Non-root users**: All containers run as UID 1001
- **Minimal filesystem**: Only necessary files included
- **Security scanning**: Multiple vulnerability scanners in CI/CD

#### Runtime Security
```dockerfile
# Enhanced security context
USER 1001
EXPOSE 8181
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8181/health').read()" || exit 1
```

### 3. Application Security

#### Input Validation
The frontend entrypoint script includes comprehensive input validation:

```bash
validate_hostname() {
    local hostname="$1"
    # RFC 1123 hostname validation
    if [[ ! "$hostname" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        echo "❌ Invalid hostname format: $hostname" >&2
        return 1
    fi
    
    # Injection protection
    if [[ "$hostname" =~ [\'\";\`\$\(\)] ]]; then
        echo "❌ Hostname contains potentially dangerous characters: $hostname" >&2
        return 1
    fi
    
    return 0
}
```

#### Secure Configuration Management
- **Environment variable validation**: All inputs validated before use
- **Secure defaults**: Production-ready defaults for all services
- **Configuration sanitization**: User inputs sanitized before processing
- **Backup and rollback**: Configuration changes backed up with timestamps

### 4. Kubernetes Security

#### Pod Security Standards
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

#### Security Context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true  # Where possible
  capabilities:
    drop:
    - ALL
  seccompProfile:
    type: RuntimeDefault
```

#### Network Security
- **Network Policies**: Restrict ingress/egress traffic
- **Service mesh ready**: Compatible with Istio, Linkerd
- **TLS encryption**: HTTPS/TLS for all external communication
- **Internal communication**: Secure inter-service communication

#### RBAC and Service Accounts
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: archon-service-account
  namespace: archon
automountServiceAccountToken: false

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: archon-role
  namespace: archon
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]  # Minimal permissions
```

### 5. Runtime Security

#### Resource Limits
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

#### Health Monitoring
- **HTTP health endpoints**: All services expose /health endpoints
- **Kubernetes probes**: Readiness and liveness probes configured
- **Security headers**: Health endpoints include security headers

```html
<meta http-equiv="X-Content-Type-Options" content="nosniff">
<meta http-equiv="X-Frame-Options" content="DENY">
```

#### Observability
- **Structured logging**: JSON logging for security event correlation
- **Metrics collection**: Prometheus-compatible metrics
- **Audit logging**: Security-relevant events logged
- **Monitoring integration**: Compatible with security monitoring tools

### 6. Secrets Management

#### Best Practices
- **No secrets in images**: Secrets injected at runtime only
- **Kubernetes secrets**: Use native Kubernetes secret management
- **External secret managers**: Compatible with Vault, AWS Secrets Manager
- **Rotation support**: Secrets can be rotated without container rebuilds

```yaml
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: archon-secrets
      key: database-password
```

### 7. Compliance and Standards

#### Security Benchmarks
- **CIS Docker Benchmark**: Images follow CIS Docker security guidelines
- **NIST Container Security**: Aligned with NIST SP 800-190
- **OWASP Top 10**: Protection against OWASP application security risks
- **PCI DSS Ready**: Suitable for PCI DSS environments with proper configuration

#### Audit and Compliance
- **Audit trails**: All build and deployment actions logged
- **Compliance reporting**: SBOM and vulnerability reports available
- **Reproducible builds**: Same source produces identical containers
- **Provenance verification**: Build attestation enables supply chain verification

## 🔍 Security Verification

### Image Verification
```bash
# Verify image signature
cosign verify ghcr.io/dapperdivers/archon-server:latest \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"

# Download and verify SBOM
cosign download sbom ghcr.io/dapperdivers/archon-server:latest

# Verify build attestation
cosign download attestation ghcr.io/dapperdivers/archon-server:latest
```

### Security Scanning
```bash
# Local vulnerability scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image ghcr.io/dapperdivers/archon-server:latest

# Configuration scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy config /path/to/kubernetes/manifests
```

## 🚨 Incident Response

### Security Monitoring
- **Vulnerability alerts**: Automated alerts for new CVEs
- **Runtime monitoring**: Anomaly detection in running containers
- **Log analysis**: Security event correlation and analysis
- **Compliance monitoring**: Continuous compliance checking

### Response Procedures
1. **Automated patching**: Critical vulnerabilities trigger automated rebuilds
2. **Rollback procedures**: Automated rollback for security incidents
3. **Incident documentation**: All security events documented
4. **Post-incident review**: Security improvements after incidents

## 📋 Security Checklist

### Pre-Deployment
- [ ] Review SBOM for acceptable dependencies
- [ ] Verify image signatures
- [ ] Run vulnerability scans
- [ ] Validate security context configuration
- [ ] Test network policies
- [ ] Verify RBAC permissions
- [ ] Check resource limits
- [ ] Validate health check endpoints

### Runtime Security
- [ ] Monitor for unusual network activity
- [ ] Watch for privilege escalation attempts
- [ ] Monitor resource usage anomalies
- [ ] Track failed authentication attempts
- [ ] Monitor file system changes
- [ ] Check for unauthorized processes

### Regular Maintenance
- [ ] Update base images monthly
- [ ] Rotate secrets quarterly
- [ ] Review network policies
- [ ] Update security contexts
- [ ] Scan for new vulnerabilities
- [ ] Review audit logs
- [ ] Test incident response procedures
- [ ] Update security documentation

This comprehensive security approach provides multiple layers of protection for Archon deployments, ensuring robust security from development through production operations.