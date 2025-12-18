# Deployment Verification Guide

This guide shows expected outputs at each stage of deployment with example commands and results.

## Table of Contents

1. [Pre-Deployment Checks](#pre-deployment-checks)
2. [Namespace Creation](#namespace-creation)
3. [Component Deployment](#component-deployment)
4. [Service Verification](#service-verification)
5. [UI Screenshots Guide](#ui-screenshots-guide)
6. [Monitoring Validation](#monitoring-validation)

---

## Pre-Deployment Checks

### Check Kubernetes Cluster

**Command:**
```bash
kubectl cluster-info
kubectl get nodes
```

**Expected Output:**
```
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

NAME                                    STATUS   ROLES           AGE   VERSION
observability-cluster-control-plane     Ready    control-plane   10m   v1.27.3
observability-cluster-worker            Ready    <none>          10m   v1.27.3
observability-cluster-worker2           Ready    <none>          10m   v1.27.3
```

---

## Namespace Creation

### Deploy Namespace

**Command:**
```bash
kubectl apply -f kubernetes/namespaces/observability.yaml
kubectl get namespace observability
```

**Expected Output:**
```
namespace/observability created

NAME             STATUS   AGE
observability    Active   5s
```

---

## Component Deployment

### 1. Prometheus Deployment

**Commands:**
```bash
kubectl apply -f kubernetes/prometheus/configmap.yaml
kubectl apply -f kubernetes/prometheus/deployment.yaml
kubectl wait --for=condition=ready pod -l app=prometheus -n observability --timeout=300s
kubectl get pods -n observability -l app=prometheus
```

**Expected Output:**
```
configmap/prometheus-config created
serviceaccount/prometheus created
clusterrole.rbac.authorization.k8s.io/prometheus created
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
deployment.apps/prometheus created
service/prometheus-service created

pod/prometheus-7d8f6c9b5d-abc12 condition met
pod/prometheus-7d8f6c9b5d-xyz78 condition met

NAME                          READY   STATUS    RESTARTS   AGE
prometheus-7d8f6c9b5d-abc12   1/1     Running   0          45s
prometheus-7d8f6c9b5d-xyz78   1/1     Running   0          45s
```

### 2. Grafana Deployment

**Commands:**
```bash
kubectl apply -f kubernetes/grafana/deployment.yaml
kubectl wait --for=condition=ready pod -l app=grafana -n observability --timeout=300s
kubectl get pods -n observability -l app=grafana
```

**Expected Output:**
```
secret/grafana-admin-credentials created
configmap/grafana-datasources created
configmap/grafana-dashboards-config created
deployment.apps/grafana created
service/grafana-service created

pod/grafana-6b9f8d5c4d-def34 condition met

NAME                       READY   STATUS    RESTARTS   AGE
grafana-6b9f8d5c4d-def34   1/1     Running   0          30s
```

### 3. Loki Deployment

**Commands:**
```bash
kubectl apply -f kubernetes/loki/deployment.yaml
kubectl wait --for=condition=ready pod -l app=loki -n observability --timeout=300s
kubectl get pods -n observability -l app=loki
```

**Expected Output:**
```
configmap/loki-config created
deployment.apps/loki created
service/loki-service created

pod/loki-5c8d7b6f9a-ghi56 condition met

NAME                     READY   STATUS    RESTARTS   AGE
loki-5c8d7b6f9a-ghi56    1/1     Running   0          25s
```

### 4. Mimir Deployment

**Commands:**
```bash
kubectl apply -f kubernetes/mimir/deployment.yaml
kubectl wait --for=condition=ready pod -l app=mimir -n observability --timeout=300s
kubectl get pods -n observability -l app=mimir
```

**Expected Output:**
```
configmap/mimir-config created
deployment.apps/mimir created
service/mimir-service created

pod/mimir-8f9c6d5e7b-jkl90 condition met

NAME                      READY   STATUS    RESTARTS   AGE
mimir-8f9c6d5e7b-jkl90    1/1     Running   0          35s
```

### 5. Alloy Deployment

**Commands:**
```bash
kubectl apply -f kubernetes/alloy/deployment.yaml
kubectl get daemonset -n observability
kubectl get pods -n observability -l app=alloy
```

**Expected Output:**
```
configmap/alloy-config created
daemonset.apps/alloy created
service/alloy-service created
serviceaccount/alloy created
clusterrole.rbac.authorization.k8s.io/alloy created
clusterrolebinding.rbac.authorization.k8s.io/alloy created

NAME    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
alloy   3         3         3       3            3           <none>          40s

NAME          READY   STATUS    RESTARTS   AGE
alloy-4n7k2   1/1     Running   0          40s
alloy-9b3x5   1/1     Running   0          40s
alloy-t6m9p   1/1     Running   0          40s
```

### 6. OpenTelemetry Collector Deployment

**Commands:**
```bash
kubectl apply -f kubernetes/opentelemetry/deployment.yaml
kubectl wait --for=condition=ready pod -l app=otel-collector -n observability --timeout=300s
kubectl get pods -n observability -l app=otel-collector
```

**Expected Output:**
```
configmap/otel-collector-config created
deployment.apps/otel-collector created
service/otel-collector-service created

pod/otel-collector-6d5f8c9b7a-mno12 condition met
pod/otel-collector-6d5f8c9b7a-pqr34 condition met

NAME                              READY   STATUS    RESTARTS   AGE
otel-collector-6d5f8c9b7a-mno12   1/1     Running   0          50s
otel-collector-6d5f8c9b7a-pqr34   1/1     Running   0          50s
```

### 7. Ingress Deployment

**Commands:**
```bash
kubectl apply -f kubernetes/ingress/ingress.yaml
kubectl get ingress -n observability
```

**Expected Output:**
```
ingress.networking.k8s.io/observability-ingress created

NAME                      CLASS   HOSTS                                                   ADDRESS         PORTS   AGE
observability-ingress     nginx   grafana.example.com,prometheus.example.com,loki...     192.168.1.100   80      10s
```

---

## Service Verification

### Check All Pods

**Command:**
```bash
kubectl get pods -n observability
```

**Expected Output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
prometheus-7d8f6c9b5d-abc12       1/1     Running   0          5m
prometheus-7d8f6c9b5d-xyz78       1/1     Running   0          5m
grafana-6b9f8d5c4d-def34          1/1     Running   0          4m
loki-5c8d7b6f9a-ghi56             1/1     Running   0          3m
mimir-8f9c6d5e7b-jkl90            1/1     Running   0          3m
alloy-4n7k2                       1/1     Running   0          2m
alloy-9b3x5                       1/1     Running   0          2m
alloy-t6m9p                       1/1     Running   0          2m
otel-collector-6d5f8c9b7a-mno12   1/1     Running   0          2m
otel-collector-6d5f8c9b7a-pqr34   1/1     Running   0          2m
```

### Check All Services

**Command:**
```bash
kubectl get svc -n observability
```

**Expected Output:**
```
NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
prometheus-service        ClusterIP   10.96.1.10      <none>        9090/TCP                     5m
grafana-service           ClusterIP   10.96.1.20      <none>        3000/TCP                     4m
loki-service              ClusterIP   10.96.1.30      <none>        3100/TCP,9096/TCP            3m
mimir-service             ClusterIP   None            <none>        8080/TCP,9095/TCP,7946/TCP   3m
alloy-service             ClusterIP   10.96.1.40      <none>        12345/TCP,4317/TCP,4318/TCP  2m
otel-collector-service    ClusterIP   10.96.1.50      <none>        4317/TCP,4318/TCP,8888/TCP   2m
```

### Health Check Commands

**Prometheus Health:**
```bash
kubectl port-forward -n observability svc/prometheus-service 9090:9090 &
sleep 3
curl -s http://localhost:9090/-/healthy
echo ""
```

**Expected Output:**
```
Prometheus Server is Healthy.
```

**Grafana Health:**
```bash
kubectl port-forward -n observability svc/grafana-service 3000:3000 &
sleep 3
curl -s http://localhost:3000/api/health | jq
```

**Expected Output:**
```json
{
  "commit": "abc123",
  "database": "ok",
  "version": "10.2.2"
}
```

**Loki Health:**
```bash
kubectl port-forward -n observability svc/loki-service 3100:3100 &
sleep 3
curl -s http://localhost:3100/ready
```

**Expected Output:**
```
ready
```

---

## UI Screenshots Guide

### Grafana Screenshots

#### 1. Port Forward to Grafana

```bash
kubectl port-forward -n observability svc/grafana-service 3000:3000
```

Then open http://localhost:3000 in your browser.

#### Screenshots to Capture:

1. **Login Page**
   - URL: http://localhost:3000
   - Default credentials: admin / admin
   - Screenshot filename: `01-grafana-login.png`

2. **Home Dashboard**
   - After login, welcome page
   - Screenshot filename: `02-grafana-home.png`

3. **Datasources Configuration**
   - Navigate to: Configuration → Data Sources
   - Should show: Prometheus, Loki, Mimir
   - Screenshot filename: `03-grafana-datasources.png`

4. **Prometheus Datasource Test**
   - Click on Prometheus datasource
   - Click "Save & Test" button
   - Should show green "Data source is working"
   - Screenshot filename: `04-prometheus-datasource-test.png`

5. **Explore Page - Metrics**
   - Navigate to: Explore
   - Select Prometheus datasource
   - Run query: `up{job="kubernetes-pods"}`
   - Screenshot filename: `05-grafana-explore-metrics.png`

6. **Explore Page - Logs**
   - In Explore, select Loki datasource
   - Run query: `{namespace="observability"}`
   - Screenshot filename: `06-grafana-explore-logs.png`

### Prometheus Screenshots

#### 2. Port Forward to Prometheus

```bash
kubectl port-forward -n observability svc/prometheus-service 9090:9090
```

Then open http://localhost:9090 in your browser.

#### Screenshots to Capture:

1. **Prometheus Home Page**
   - URL: http://localhost:9090
   - Screenshot filename: `07-prometheus-home.png`

2. **Prometheus Targets**
   - Navigate to: Status → Targets
   - Should show all targets with "UP" status
   - Screenshot filename: `08-prometheus-targets.png`

3. **Prometheus Graph**
   - Navigate to: Graph
   - Query: `up`
   - Click "Execute"
   - Switch to "Graph" tab
   - Screenshot filename: `09-prometheus-graph.png`

4. **Prometheus Configuration**
   - Navigate to: Status → Configuration
   - Shows prometheus.yml content
   - Screenshot filename: `10-prometheus-config.png`

### Expected Targets Status

When viewing http://localhost:9090/targets, you should see:

```
Endpoint                                          State    Labels
─────────────────────────────────────────────────────────────────────
http://prometheus-service:9090/metrics           UP       job="prometheus"
https://kubernetes.default.svc:443/metrics        UP       job="kubernetes-apiservers"
http://alloy-4n7k2:12345/metrics                  UP       job="grafana-alloy"
http://otel-collector-...:8888/metrics            UP       job="opentelemetry-collector"
```

---

## Monitoring Validation

### Test Prometheus Scraping

**Command:**
```bash
kubectl port-forward -n observability svc/prometheus-service 9090:9090 &
sleep 3

# Query for all targets
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

**Expected Output:**
```json
{
  "job": "prometheus",
  "health": "up"
}
{
  "job": "kubernetes-apiservers",
  "health": "up"
}
{
  "job": "kubernetes-nodes",
  "health": "up"
}
{
  "job": "kubernetes-pods",
  "health": "up"
}
```

### Test Metrics Query

**Command:**
```bash
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result[] | {metric: .metric, value: .value[1]}'
```

**Expected Output:**
```json
{
  "metric": {
    "job": "prometheus",
    "instance": "prometheus-service:9090"
  },
  "value": "1"
}
{
  "metric": {
    "job": "kubernetes-pods",
    "pod": "grafana-6b9f8d5c4d-def34"
  },
  "value": "1"
}
```

### Test Grafana Datasources

**Command:**
```bash
kubectl port-forward -n observability svc/grafana-service 3000:3000 &
sleep 3

curl -s -u admin:admin http://localhost:3000/api/datasources | jq '.[] | {name: .name, type: .type, url: .url}'
```

**Expected Output:**
```json
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://prometheus-service.observability.svc.cluster.local:9090"
}
{
  "name": "Loki",
  "type": "loki",
  "url": "http://loki-service.observability.svc.cluster.local:3100"
}
{
  "name": "Mimir",
  "type": "prometheus",
  "url": "http://mimir-service.observability.svc.cluster.local:8080/prometheus"
}
```

### Test Log Collection

**Command:**
```bash
kubectl port-forward -n observability svc/loki-service 3100:3100 &
sleep 3

# Query recent logs
curl -G -s 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={namespace="observability"}' \
  --data-urlencode 'limit=5' | jq '.data.result[0]'
```

**Expected Output:**
```json
{
  "stream": {
    "namespace": "observability",
    "pod": "prometheus-7d8f6c9b5d-abc12",
    "container": "prometheus"
  },
  "values": [
    [
      "1702900800000000000",
      "level=info ts=2023-12-18T10:00:00.000Z caller=main.go:123 msg=\"Server is ready to receive web requests.\""
    ]
  ]
}
```

---

## Deployment Success Criteria

✅ **All pods are Running**
```bash
kubectl get pods -n observability --no-headers | awk '{print $3}' | sort -u
# Should output: Running
```

✅ **All services are available**
```bash
kubectl get svc -n observability --no-headers | wc -l
# Should output: 6
```

✅ **Prometheus has active targets**
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
# Should output: > 0
```

✅ **Grafana datasources are configured**
```bash
curl -s -u admin:admin http://localhost:3000/api/datasources | jq 'length'
# Should output: 3
```

✅ **Loki is collecting logs**
```bash
curl -s 'http://localhost:3100/loki/api/v1/label' | jq '.data | length'
# Should output: > 0
```

---

## Troubleshooting

If any component is not working:

1. **Check pod logs:**
   ```bash
   kubectl logs -n observability <pod-name>
   ```

2. **Check pod events:**
   ```bash
   kubectl describe pod -n observability <pod-name>
   ```

3. **Check service endpoints:**
   ```bash
   kubectl get endpoints -n observability
   ```

4. **Test service connectivity:**
   ```bash
   kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- curl -v http://prometheus-service.observability.svc.cluster.local:9090/-/healthy
   ```

---

## Next Steps

After successful deployment:

1. Import pre-built dashboards (see FAQ.md)
2. Configure alerting rules (see scenarios/)
3. Deploy sample application (see examples/sample-app/)
4. Set up persistent storage (see examples/production/)
5. Configure TLS/SSL (see DEPLOYMENT.md)

---

## Quick Reference

| Component | Port Forward Command | URL |
|-----------|---------------------|-----|
| Grafana | `kubectl port-forward -n observability svc/grafana-service 3000:3000` | http://localhost:3000 |
| Prometheus | `kubectl port-forward -n observability svc/prometheus-service 9090:9090` | http://localhost:9090 |
| Loki | `kubectl port-forward -n observability svc/loki-service 3100:3100` | http://localhost:3100 |
| Mimir | `kubectl port-forward -n observability svc/mimir-service 8080:8080` | http://localhost:8080 |

**Default Credentials:**
- Grafana: admin / admin (change after first login!)
