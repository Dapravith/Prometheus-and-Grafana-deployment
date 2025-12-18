# Step-by-Step Implementation Guide

## Complete Hands-On Tutorial for Observability Stack

This guide provides a complete, real-world implementation of the observability stack from scratch to production.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Environment Setup](#phase-1-environment-setup)
3. [Phase 2: Deploy Core Components](#phase-2-deploy-core-components)
4. [Phase 3: Configure Monitoring](#phase-3-configure-monitoring)
5. [Phase 4: Test and Validate](#phase-4-test-and-validate)
6. [Phase 5: Production Hardening](#phase-5-production-hardening)
7. [Phase 6: CI/CD Integration](#phase-6-cicd-integration)

---

## Prerequisites

### Required Tools

```bash
# Check if tools are installed
command -v kubectl >/dev/null 2>&1 || echo "kubectl not found"
command -v docker >/dev/null 2>&1 || echo "docker not found"
command -v git >/dev/null 2>&1 || echo "git not found"

# Install kubectl (if needed)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install kind (Kubernetes in Docker)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### System Requirements

- **CPU**: 4+ cores
- **RAM**: 8GB+ available
- **Disk**: 20GB+ free space
- **OS**: Linux, macOS, or WSL2 on Windows

---

## Phase 1: Environment Setup

### Step 1.1: Create Kubernetes Cluster

```bash
# Create cluster configuration
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: observability-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# Create the cluster
kind create cluster --config kind-config.yaml

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

**Expected Output:**
```
NAME                                    STATUS   ROLES           AGE   VERSION
observability-cluster-control-plane     Ready    control-plane   1m    v1.27.3
observability-cluster-worker            Ready    <none>          1m    v1.27.3
observability-cluster-worker2           Ready    <none>          1m    v1.27.3
```

### Step 1.2: Install Ingress Controller

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Verify
kubectl get pods -n ingress-nginx
```

### Step 1.3: Clone Repository

```bash
# Clone the observability stack repository
git clone https://github.com/Dapravith/Prometheus-and-Grafana-deployment.git
cd Prometheus-and-Grafana-deployment

# Checkout the appropriate branch
git checkout feature/observability-prometheus

# Review the structure
tree -L 2
```

---

## Phase 2: Deploy Core Components

### Step 2.1: Deploy Namespace

```bash
# Create observability namespace
kubectl apply -f kubernetes/namespaces/observability.yaml

# Verify
kubectl get namespace observability
```

### Step 2.2: Deploy Prometheus

```bash
# Deploy Prometheus configuration
kubectl apply -f kubernetes/prometheus/configmap.yaml

# Deploy Prometheus
kubectl apply -f kubernetes/prometheus/deployment.yaml

# Wait for Prometheus to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n observability --timeout=300s

# Check status
kubectl get pods -n observability -l app=prometheus
```

**Verify Prometheus is working:**
```bash
# Port forward to access Prometheus UI
kubectl port-forward -n observability svc/prometheus-service 9090:9090 &

# Open browser to http://localhost:9090
# Or test with curl
curl -s http://localhost:9090/-/healthy
```

### Step 2.3: Deploy Grafana

```bash
# Deploy Grafana with datasources
kubectl apply -f kubernetes/grafana/deployment.yaml

# Wait for Grafana to be ready
kubectl wait --for=condition=ready pod -l app=grafana -n observability --timeout=300s

# Get admin password
kubectl get secret grafana-admin-credentials -n observability -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

**Access Grafana:**
```bash
# Port forward
kubectl port-forward -n observability svc/grafana-service 3000:3000 &

# Open http://localhost:3000
# Login: admin / admin (change this!)
```

**First Login Steps:**
1. Open http://localhost:3000
2. Login with admin/admin
3. Change password when prompted
4. Go to Configuration → Data Sources
5. Verify Prometheus, Loki, and Mimir are configured

### Step 2.4: Deploy Loki (Log Aggregation)

```bash
# Deploy Loki
kubectl apply -f kubernetes/loki/deployment.yaml

# Wait for Loki
kubectl wait --for=condition=ready pod -l app=loki -n observability --timeout=300s

# Verify Loki is healthy
kubectl port-forward -n observability svc/loki-service 3100:3100 &
curl http://localhost:3100/ready
```

### Step 2.5: Deploy Mimir (Long-term Storage)

```bash
# Deploy Mimir
kubectl apply -f kubernetes/mimir/deployment.yaml

# Wait for Mimir
kubectl wait --for=condition=ready pod -l app=mimir -n observability --timeout=300s

# Check status
kubectl get pods -n observability -l app=mimir
```

### Step 2.6: Deploy Grafana Alloy (Collection Agent)

```bash
# Deploy Alloy as DaemonSet
kubectl apply -f kubernetes/alloy/deployment.yaml

# Verify Alloy is running on all nodes
kubectl get daemonset -n observability
kubectl get pods -n observability -l app=alloy
```

### Step 2.7: Deploy OpenTelemetry Collector

```bash
# Deploy OpenTelemetry Collector
kubectl apply -f kubernetes/opentelemetry/deployment.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=otel-collector -n observability --timeout=300s

# Verify 2 replicas are running
kubectl get pods -n observability -l app=otel-collector
```

### Step 2.8: Deploy Ingress

```bash
# Update domain in ingress.yaml (optional, for local testing use localhost)
# Edit kubernetes/ingress/ingress.yaml if needed

# Deploy ingress
kubectl apply -f kubernetes/ingress/ingress.yaml

# Get ingress status
kubectl get ingress -n observability
```

---

## Phase 3: Configure Monitoring

### Step 3.1: Verify All Components Are Running

```bash
# Check all pods
kubectl get pods -n observability

# Expected output (all Running):
NAME                              READY   STATUS    RESTARTS   AGE
prometheus-xxxxxx-yyyyy          1/1     Running   0          5m
prometheus-xxxxxx-zzzzz          1/1     Running   0          5m
grafana-xxxxxx-yyyyy             1/1     Running   0          4m
loki-xxxxxx-yyyyy                1/1     Running   0          3m
mimir-xxxxxx-yyyyy               1/1     Running   0          2m
alloy-xxxxx                      1/1     Running   0          1m
alloy-yyyyy                      1/1     Running   0          1m
otel-collector-xxxxxx-yyyyy      1/1     Running   0          1m
otel-collector-xxxxxx-zzzzz      1/1     Running   0          1m
```

### Step 3.2: Configure Prometheus Targets

```bash
# Port forward to Prometheus
kubectl port-forward -n observability svc/prometheus-service 9090:9090 &

# Open http://localhost:9090/targets
# Verify all targets are UP:
# - prometheus
# - kubernetes-apiservers
# - kubernetes-nodes
# - kubernetes-pods
```

### Step 3.3: Set Up Grafana Dashboards

```bash
# Access Grafana
kubectl port-forward -n observability svc/grafana-service 3000:3000 &

# Import dashboards:
# 1. Go to http://localhost:3000
# 2. Click "+" → "Import"
# 3. Import these dashboard IDs:
#    - 315 (Kubernetes cluster monitoring)
#    - 1860 (Node Exporter Full)
#    - 13639 (Kubernetes / API server)
```

**Create Custom Dashboard:**

1. Go to Dashboards → New Dashboard
2. Add Panel
3. Select Prometheus datasource
4. Add queries:

```promql
# CPU Usage
sum(rate(container_cpu_usage_seconds_total{namespace!=""}[5m])) by (namespace)

# Memory Usage
sum(container_memory_usage_bytes{namespace!=""}) by (namespace)

# Pod Count
count(kube_pod_info) by (namespace)
```

---

## Phase 4: Test and Validate

### Step 4.1: Deploy Sample Application

```bash
# Deploy sample app with monitoring annotations
kubectl apply -f examples/sample-app/deployment.yaml

# Verify deployment
kubectl get pods -n default -l app=sample-app
```

### Step 4.2: Generate Traffic

```bash
# Port forward to sample app
kubectl port-forward -n default svc/sample-app-service 8080:8080 &

# Generate some load
for i in {1..1000}; do
  curl -s http://localhost:8080/metrics > /dev/null
  echo "Request $i completed"
  sleep 0.1
done
```

### Step 4.3: Verify Metrics Collection

```bash
# Check Prometheus is scraping the sample app
# Go to http://localhost:9090/targets
# Look for sample-app target

# Query sample app metrics
# Go to http://localhost:9090/graph
# Run query:
up{job="kubernetes-pods", pod=~"sample-app.*"}
```

### Step 4.4: Verify Log Collection

```bash
# Check logs in Grafana
# 1. Go to http://localhost:3000
# 2. Go to Explore
# 3. Select Loki datasource
# 4. Run query:
{namespace="default", pod=~"sample-app.*"}
```

### Step 4.5: Test Alerts

```bash
# Create a test pod that uses high CPU
kubectl run cpu-test --image=progrium/stress --restart=Never -- --cpu 2 --timeout 60s

# Watch in Prometheus
# Should see high CPU usage
# Alert should fire if configured
```

---

## Phase 5: Production Hardening

### Step 5.1: Enable Persistent Storage

```bash
# Create PVC for Prometheus
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: standard
EOF

# Update Prometheus deployment to use PVC
# (Edit kubernetes/prometheus/deployment.yaml)
```

### Step 5.2: Configure Alerting

```bash
# Create alert rules file
cat <<EOF > prometheus-alerts.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
  namespace: observability
data:
  alerts.yml: |
    groups:
    - name: kubernetes_alerts
      rules:
      - alert: PodDown
        expr: up{job="kubernetes-pods"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ \$labels.pod }} is down"
      
      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ \$labels.pod }} high memory"
EOF

kubectl apply -f prometheus-alerts.yaml
```

### Step 5.3: Secure Grafana

```bash
# Create secure password
SECURE_PASSWORD=$(openssl rand -base64 32)

# Update secret
kubectl create secret generic grafana-admin-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$SECURE_PASSWORD" \
  -n observability \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Grafana to pick up new password
kubectl rollout restart deployment grafana -n observability

# Save password securely
echo "Grafana admin password: $SECURE_PASSWORD" > ~/.grafana-credentials
chmod 600 ~/.grafana-credentials
```

### Step 5.4: Configure Network Policies

```bash
# Create network policy for Prometheus
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-network-policy
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: grafana
    ports:
    - protocol: TCP
      port: 9090
  egress:
  - {}
EOF
```

---

## Phase 6: CI/CD Integration

### Step 6.1: Set Up GitHub Actions

The CI/CD workflows are already in `.github/workflows/`:
- `ci-cd.yml` - Main deployment pipeline
- `health-check.yml` - Continuous health monitoring

### Step 6.2: Test CI/CD Pipeline

```bash
# Push changes to trigger workflow
git add .
git commit -m "Test CI/CD pipeline"
git push origin feature/observability-prometheus

# Check GitHub Actions tab for workflow run
```

---

## Verification Checklist

Use this checklist to verify your deployment:

```bash
# Run verification script
cat <<'EOF' > verify-deployment.sh
#!/bin/bash

echo "=== Observability Stack Verification ==="
echo ""

# Check all pods
echo "1. Checking pods..."
kubectl get pods -n observability | grep -E "Running|NAME"
echo ""

# Check services
echo "2. Checking services..."
kubectl get svc -n observability
echo ""

# Check Prometheus
echo "3. Testing Prometheus..."
kubectl port-forward -n observability svc/prometheus-service 9090:9090 >/dev/null 2>&1 &
PF_PID=$!
sleep 3
curl -f -s http://localhost:9090/-/healthy && echo "✓ Prometheus healthy" || echo "✗ Prometheus unhealthy"
kill $PF_PID 2>/dev/null
echo ""

# Check Grafana
echo "4. Testing Grafana..."
kubectl port-forward -n observability svc/grafana-service 3000:3000 >/dev/null 2>&1 &
PF_PID=$!
sleep 3
curl -f -s http://localhost:3000/api/health && echo "✓ Grafana healthy" || echo "✗ Grafana unhealthy"
kill $PF_PID 2>/dev/null
echo ""

# Check Loki
echo "5. Testing Loki..."
kubectl port-forward -n observability svc/loki-service 3100:3100 >/dev/null 2>&1 &
PF_PID=$!
sleep 3
curl -f -s http://localhost:3100/ready && echo "✓ Loki healthy" || echo "✗ Loki unhealthy"
kill $PF_PID 2>/dev/null
echo ""

echo "=== Verification Complete ==="
EOF

chmod +x verify-deployment.sh
./verify-deployment.sh
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n observability

# Check logs
kubectl logs <pod-name> -n observability

# Common issues:
# - Insufficient resources
# - Image pull errors
# - Configuration errors
```

### Metrics Not Showing

```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-service 9090:9090
# Visit http://localhost:9090/targets

# Check if pods have correct annotations
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 annotations
```

### Access Issues

```bash
# Check ingress
kubectl get ingress -n observability
kubectl describe ingress observability-ingress -n observability

# Check services
kubectl get svc -n observability
```

---

## Next Steps

1. ✓ Review [Scenario-Based Tutorials](../scenarios/README.md)
2. ✓ Set up [Production Best Practices](../examples/production/README.md)
3. ✓ Configure [Advanced Monitoring](./advanced-monitoring.md)
4. ✓ Implement [Custom Dashboards](./custom-dashboards.md)

---

## Commands Quick Reference

```bash
# Deployment
kubectl apply -f kubernetes/namespaces/
kubectl apply -f kubernetes/prometheus/
kubectl apply -f kubernetes/grafana/
kubectl apply -f kubernetes/loki/
kubectl apply -f kubernetes/mimir/
kubectl apply -f kubernetes/alloy/
kubectl apply -f kubernetes/opentelemetry/
kubectl apply -f kubernetes/ingress/

# Monitoring
kubectl get pods -n observability
kubectl logs -f <pod-name> -n observability
kubectl port-forward -n observability svc/grafana-service 3000:3000
kubectl port-forward -n observability svc/prometheus-service 9090:9090

# Troubleshooting
kubectl describe pod <pod-name> -n observability
kubectl top pods -n observability
kubectl get events -n observability --sort-by='.lastTimestamp'

# Cleanup
kubectl delete namespace observability
kind delete cluster --name observability-cluster
```

---

## Success Criteria

Your deployment is successful when:

- ✅ All pods are Running
- ✅ Prometheus is scraping targets
- ✅ Grafana shows metrics
- ✅ Loki is collecting logs
- ✅ No errors in pod logs
- ✅ Sample app metrics visible
- ✅ Health checks passing

**Congratulations! Your observability stack is now running!** 🎉
