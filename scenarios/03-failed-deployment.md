# Scenario 3: Failed Deployment Recovery

## Problem Description

A new deployment has failed, causing service disruption. Pods are not starting correctly, users are experiencing errors, and you need to quickly identify the issue and rollback or fix the deployment.

## Symptoms

- New pods stuck in `CrashLoopBackOff` or `ImagePullBackOff`
- Increased error rates from application
- Users reporting 502/503 errors
- Old pods terminating before new ones are ready

## Step 1: Detect the Failed Deployment

### Quick Detection

```bash
# Check recent deployments
kubectl get deployments -A

# Look for pods not ready
kubectl get pods -A | grep -v "Running\|Completed"

# Check events for errors
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

### Detailed Investigation

```bash
# Check specific deployment status
kubectl rollout status deployment/api-server -n production

# Example output showing failure:
Waiting for deployment "api-server" rollout to finish: 1 out of 3 new replicas have been updated...
error: deployment "api-server" exceeded its progress deadline
```

## Step 2: Identify the Issue

### Check Pod Status

```bash
# Get pod details
kubectl get pods -n production -l app=api-server

# Example problematic output:
NAME                          READY   STATUS             RESTARTS   AGE
api-server-new-abc123        0/1     ImagePullBackOff   0          5m
api-server-new-def456        0/1     CrashLoopBackOff   3          5m
api-server-old-xyz789        1/1     Running            0          2d
```

### Investigate Common Issues

#### Issue 1: Image Pull Errors

```bash
# Describe pod to see events
kubectl describe pod api-server-new-abc123 -n production

# Look for ImagePullBackOff or ErrImagePull:
Events:
  Type     Reason     Message
  ----     ------     -------
  Warning  Failed     Failed to pull image "myregistry.io/api-server:v2.0.1": rpc error: code = Unknown desc = Error response from daemon: manifest for myregistry.io/api-server:v2.0.1 not found
  Warning  Failed     Error: ErrImagePull
  Normal   BackOff    Back-off pulling image "myregistry.io/api-server:v2.0.1"
```

**Root Cause**: Image tag doesn't exist or typo in image name

#### Issue 2: Application Crashes

```bash
# Check logs of crashing pod
kubectl logs api-server-new-def456 -n production

# Example error:
Error: Cannot find module 'missing-dependency'
    at Function.Module._resolveFilename (internal/modules/cjs/loader.js:636:15)
    at Function.Module._load (internal/modules/cjs/loader.js:562:25)
```

**Root Cause**: Missing dependency in new version

#### Issue 3: Configuration Errors

```bash
# Check pod logs for config errors
kubectl logs api-server-new-def456 -n production --tail=50

# Example error:
Fatal error: Database connection failed
Error: getaddrinfo ENOTFOUND database-new.production.svc.cluster.local
```

**Root Cause**: Incorrect configuration (wrong database host)

#### Issue 4: Health Check Failures

```bash
# Describe pod
kubectl describe pod api-server-new-def456 -n production

# Look for readiness/liveness probe failures:
Events:
  Warning  Unhealthy  Readiness probe failed: HTTP probe failed with statuscode: 500
  Warning  Unhealthy  Liveness probe failed: Get "http://10.1.2.3:8080/health": dial tcp 10.1.2.3:8080: connect: connection refused
```

**Root Cause**: Application not starting on expected port or health endpoint broken

## Step 3: Immediate Response - Rollback

### Quick Rollback

```bash
# Rollback to previous version immediately
kubectl rollout undo deployment/api-server -n production

# Verify rollback
kubectl rollout status deployment/api-server -n production

# Check pods are back to running
kubectl get pods -n production -l app=api-server
```

### Verify Services Restored

```bash
# Test endpoint
kubectl port-forward -n production svc/api-server-service 8080:8080 &
curl http://localhost:8080/health

# Check in Grafana
# Look at error rate dashboard - should drop after rollback
```

### Monitor in Prometheus

```promql
# Query error rate
rate(http_requests_total{status=~"5..",namespace="production"}[5m])

# Should see spike during failed deployment, drop after rollback
```

## Step 4: Root Cause Analysis

Based on the issue type:

### Fix 1: Image Pull Error

```bash
# Check available tags
docker images | grep api-server

# Or query registry
curl -X GET https://myregistry.io/v2/api-server/tags/list

# Found: v2.0.1 doesn't exist, should be v2.1.0

# Update deployment
kubectl set image deployment/api-server api-server=myregistry.io/api-server:v2.1.0 -n production
```

### Fix 2: Missing Dependency

```bash
# Build new image with dependency
# In Dockerfile:
# FROM node:18
# COPY package*.json ./
# RUN npm ci --production
# COPY . .
# CMD ["node", "app.js"]

# Build and push
docker build -t myregistry.io/api-server:v2.0.2 .
docker push myregistry.io/api-server:v2.0.2

# Deploy fixed version
kubectl set image deployment/api-server api-server=myregistry.io/api-server:v2.0.2 -n production
```

### Fix 3: Configuration Error

```bash
# Update ConfigMap
kubectl edit configmap api-server-config -n production

# Change:
# database_host: database-new.production.svc.cluster.local
# To:
# database_host: database.production.svc.cluster.local

# Restart deployment to pick up config
kubectl rollout restart deployment/api-server -n production
```

### Fix 4: Health Check Configuration

```yaml
# Update deployment health checks
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  template:
    spec:
      containers:
      - name: api-server
        livenessProbe:
          httpGet:
            path: /health
            port: 3000  # Fixed: was 8080, should be 3000
          initialDelaySeconds: 30  # Give app time to start
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 10  # Shorter delay for readiness
          periodSeconds: 5
```

## Step 5: Safe Redeployment

### Test in Staging First

```bash
# Deploy to staging
kubectl set image deployment/api-server api-server=myregistry.io/api-server:v2.0.2 -n staging

# Wait and monitor
kubectl rollout status deployment/api-server -n staging

# Run tests
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl http://api-server-service.staging.svc.cluster.local:8080/health
```

### Canary Deployment (Progressive)

```bash
# Deploy with canary strategy
# Update only 1 replica first
kubectl scale deployment api-server-new -n production --replicas=1

# Monitor for 10 minutes
# Check error rates, latency, logs

# If good, scale up gradually
kubectl scale deployment api-server-new -n production --replicas=2
# Wait and monitor
kubectl scale deployment api-server-new -n production --replicas=3
# Wait and monitor

# Scale down old version
kubectl scale deployment api-server-old -n production --replicas=0
```

### Blue-Green Deployment

```bash
# Keep old deployment (blue) running
# Deploy new version as separate deployment (green)
kubectl apply -f api-server-green-deployment.yaml

# Test green deployment
kubectl port-forward -n production svc/api-server-green-service 8080:8080 &
# Run tests

# Switch service to green
kubectl patch service api-server-service -n production -p '{"spec":{"selector":{"version":"green"}}}'

# Monitor closely
# If issues, switch back to blue immediately
kubectl patch service api-server-service -n production -p '{"spec":{"selector":{"version":"blue"}}}'
```

## Step 6: Prevention Measures

### 1. Implement Automated Testing

```yaml
# .github/workflows/deploy.yml
name: Deploy with Testing
on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build image
        run: docker build -t api-server:${{ github.sha }} .
      
      - name: Run integration tests
        run: |
          docker run -d --name test-api api-server:${{ github.sha }}
          sleep 10
          curl -f http://localhost:8080/health || exit 1
      
      - name: Push image only if tests pass
        run: docker push myregistry.io/api-server:${{ github.sha }}
```

### 2. Set Up Deployment Guards

```yaml
# deployment.yaml with proper rolling update
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # At most 1 extra pod during update
      maxUnavailable: 0  # Never have fewer than desired pods
  minReadySeconds: 30    # Wait 30s after pod ready before continuing
  progressDeadlineSeconds: 600  # Fail deployment if not progressing after 10min
```

### 3. Automated Rollback

```yaml
# ArgoCD or similar for automatic rollback
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-server
spec:
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: error-rate
          args:
          - name: service-name
            value: api-server
      - setWeight: 50
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: error-rate
      - setWeight: 100
  
  # Auto rollback if analysis fails
  abortScaleDownDelaySeconds: 30
```

### 4. Alerting on Failed Deployments

```yaml
# prometheus-alerts.yaml
groups:
- name: deployment_alerts
  rules:
  - alert: DeploymentFailed
    expr: kube_deployment_status_condition{condition="Progressing",status="false"} == 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Deployment {{ $labels.deployment }} failed"
      description: "Deployment has not made progress in 5 minutes"
  
  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.pod }} crash looping"
  
  - alert: ImagePullError
    expr: kube_pod_container_status_waiting_reason{reason="ImagePullBackOff"} == 1
    labels:
      severity: critical
    annotations:
      summary: "Cannot pull image for {{ $labels.pod }}"
```

### 5. Pre-deployment Checklist

```markdown
# DEPLOY_CHECKLIST.md

Before deploying to production:

- [ ] Code reviewed and approved
- [ ] All tests passing in CI/CD
- [ ] Deployed and tested in staging
- [ ] Database migrations tested (if any)
- [ ] Rollback plan documented
- [ ] On-call engineer notified
- [ ] Monitoring dashboards open
- [ ] Image tag verified in registry
- [ ] ConfigMaps/Secrets updated if needed
- [ ] Resource limits reviewed
- [ ] Health check endpoints tested
- [ ] Load testing completed (for major changes)
```

## Step 7: Post-Incident Review

### Document the Incident

```markdown
# Post-Incident Report: Failed Deployment 2023-12-18

## Timeline
- 14:00 - Deployment started (v2.0.1)
- 14:05 - Pods failing to start
- 14:07 - Alert fired: PodCrashLooping
- 14:10 - Investigation started
- 14:15 - Rollback initiated
- 14:18 - Service restored
- 14:30 - Root cause identified
- 15:00 - Fixed version deployed (v2.0.2)

## Root Cause
Missing dependency in package.json

## Impact
- 18 minutes of degraded service
- 500 errors served to ~1000 requests
- No data loss

## Action Items
- [ ] Add dependency check to CI/CD
- [ ] Improve health check to detect missing deps
- [ ] Update deployment checklist
- [ ] Train team on rollback procedures
```

## Commands Summary

```bash
# Detection
kubectl get deployments -A
kubectl get pods -A | grep -v Running
kubectl rollout status deployment/<name> -n <namespace>

# Investigation
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Rollback
kubectl rollout undo deployment/<name> -n <namespace>
kubectl rollout status deployment/<name> -n <namespace>

# Fix and Redeploy
kubectl set image deployment/<name> <container>=<image>:<tag> -n <namespace>
kubectl rollout restart deployment/<name> -n <namespace>

# Monitoring
kubectl get pods -n <namespace> -w
kubectl port-forward -n <namespace> svc/<service> 8080:8080
```

## Monitoring Queries

```promql
# Deployment success rate
rate(kube_deployment_status_replicas_updated[5m]) / 
rate(kube_deployment_spec_replicas[5m])

# Pod restart rate
rate(kube_pod_container_status_restarts_total[5m])

# Failed deployments
kube_deployment_status_condition{condition="Progressing",status="false"}

# Image pull errors
kube_pod_container_status_waiting_reason{reason=~"ImagePullBackOff|ErrImagePull"}
```

## Key Takeaways

1. ✓ Always have a rollback plan before deploying
2. ✓ Monitor deployments in real-time
3. ✓ Use progressive rollout strategies (canary/blue-green)
4. ✓ Test in staging first
5. ✓ Automate health checks and rollbacks
6. ✓ Document incidents for learning
7. ✓ Set up alerts for deployment failures

## Next Steps

- Review [Scenario 4: Disk Space Monitoring](./04-disk-space-alert.md)
- Implement automated rollback policies
- Set up deployment dashboards in Grafana
- Create runbook for deployment failures
