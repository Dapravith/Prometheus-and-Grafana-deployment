# Scenario 1: High CPU Usage Detection and Resolution

## Problem Description

Your application pods are experiencing high CPU usage, causing slow response times and potential service degradation. Users are complaining about slow page loads, and the system is becoming unresponsive.

## Symptoms

- Slow API response times
- Increased latency in user requests
- Pods approaching CPU limits
- Potential pod throttling
- Application timeouts

## Step 1: Detect the Issue

### Using Grafana

1. **Access Grafana**:
   ```bash
   kubectl port-forward -n observability svc/grafana-service 3000:3000
   ```
   Open http://localhost:3000

2. **Check CPU Dashboard**:
   - Navigate to: Dashboards → Kubernetes → CPU Usage
   - Look for pods with consistently high CPU (>80%)

### Using Prometheus

1. **Port forward to Prometheus**:
   ```bash
   kubectl port-forward -n observability svc/prometheus-service 9090:9090
   ```

2. **Run PromQL query**:
   ```promql
   # CPU usage by pod (percentage)
   sum(rate(container_cpu_usage_seconds_total{namespace!="kube-system"}[5m])) by (pod, namespace) * 100
   
   # Top 10 CPU consuming pods
   topk(10, sum(rate(container_cpu_usage_seconds_total[5m])) by (pod))
   ```

### Using kubectl

```bash
# Check current CPU usage
kubectl top pods -A --sort-by=cpu

# Example output:
NAMESPACE     NAME                          CPU(cores)   MEMORY(bytes)
production    api-server-abc123             950m         512Mi
production    worker-def456                 850m         1024Mi
```

## Step 2: Investigate the Root Cause

### Check Pod Details

```bash
# Get detailed pod information
kubectl describe pod api-server-abc123 -n production

# Check pod logs for errors or patterns
kubectl logs api-server-abc123 -n production --tail=100

# Check recent events
kubectl get events -n production --sort-by='.lastTimestamp' | grep api-server
```

### Analyze Application Metrics

1. **Check application logs in Loki**:
   ```bash
   # Port forward to Loki
   kubectl port-forward -n observability svc/loki-service 3100:3100
   ```

   In Grafana Explore with Loki datasource:
   ```logql
   {namespace="production", pod=~"api-server.*"} |= "error" or "timeout" or "slow"
   ```

2. **Check for memory leaks causing CPU spikes**:
   ```promql
   # Memory usage trend
   container_memory_usage_bytes{namespace="production", pod=~"api-server.*"}
   ```

3. **Check request rate**:
   ```promql
   # Request rate spike?
   rate(http_requests_total{namespace="production"}[5m])
   ```

### Common Root Causes

1. **Traffic Spike**: Sudden increase in user requests
2. **Infinite Loop**: Bug in code causing endless processing
3. **Inefficient Algorithm**: O(n²) complexity on large datasets
4. **Resource Contention**: Multiple CPU-intensive operations
5. **External API Delays**: Waiting synchronously for slow APIs

## Step 3: Identify the Specific Issue

### Example Investigation

```bash
# Check if it's a traffic spike
kubectl logs api-server-abc123 -n production | grep -c "HTTP" | head -1000
# If significantly higher than normal, it's traffic-related

# Check for specific error patterns
kubectl logs api-server-abc123 -n production | grep -E "timeout|slow|retry"

# Check application metrics endpoint
kubectl port-forward api-server-abc123 -n production 8080:8080
curl http://localhost:8080/metrics | grep http_request

# Example finding: 
# http_requests_total{method="POST",endpoint="/api/v1/process"} 50000
# This endpoint is being hit excessively
```

## Step 4: Implement Solution

### Solution 1: Scale the Application (Quick Fix)

```bash
# Increase replicas to handle load
kubectl scale deployment api-server -n production --replicas=5

# Verify scaling
kubectl get pods -n production -w

# Check if CPU usage dropped
kubectl top pods -n production
```

### Solution 2: Increase CPU Limits

Edit deployment:
```bash
kubectl edit deployment api-server -n production
```

Update resources:
```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"    # Increased from 1000m
    memory: "1Gi"
```

### Solution 3: Fix the Code (Permanent Fix)

If the issue is a code problem:

```python
# BAD: O(n²) complexity
for item in large_list:
    for other in large_list:
        process(item, other)

# GOOD: O(n) with proper data structure
item_map = {item.id: item for item in large_list}
for item in large_list:
    if item.related_id in item_map:
        process(item, item_map[item.related_id])
```

### Solution 4: Implement Rate Limiting

```yaml
# Add rate limiting to deployment
apiVersion: v1
kind: ConfigMap
metadata:
  name: rate-limit-config
  namespace: production
data:
  nginx.conf: |
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    
    location /api/ {
        limit_req zone=api burst=20;
        proxy_pass http://backend;
    }
```

## Step 5: Verify the Fix

```bash
# Monitor CPU usage after fix
watch -n 5 'kubectl top pods -n production | grep api-server'

# Check Prometheus for sustained improvement
# Run this query and verify downward trend:
```
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="production",pod=~"api-server.*"}[5m])) * 100
```

## Step 6: Set Up Prevention

### Implement Monitoring Alerts

Create alerting rule:

```yaml
# prometheus-alerts.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
  namespace: observability
data:
  alerts.yml: |
    groups:
    - name: cpu_alerts
      rules:
      - alert: HighCPUUsage
        expr: sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace) > 0.8
        for: 5m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High CPU usage detected on {{ $labels.pod }}"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is using {{ $value }}% CPU"
      
      - alert: CriticalCPUUsage
        expr: sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace) > 0.95
        for: 2m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Critical CPU usage on {{ $labels.pod }}"
          description: "Pod {{ $labels.pod }} is at {{ $value }}% CPU - immediate action required"
```

Apply the alert:
```bash
kubectl apply -f prometheus-alerts.yaml
```

### Set Up Horizontal Pod Autoscaling (HPA)

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-server-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

Apply HPA:
```bash
kubectl apply -f hpa.yaml

# Verify HPA is working
kubectl get hpa -n production -w
```

### Create Grafana Dashboard

Import this dashboard JSON or create panels for:

1. **CPU Usage by Pod** (time series)
   ```promql
   sum(rate(container_cpu_usage_seconds_total{namespace="production"}[5m])) by (pod) * 100
   ```

2. **CPU Throttling Events** (counter)
   ```promql
   rate(container_cpu_cfs_throttled_seconds_total{namespace="production"}[5m])
   ```

3. **Request Rate** (graph)
   ```promql
   sum(rate(http_requests_total{namespace="production"}[5m])) by (endpoint)
   ```

## Commands Summary

```bash
# Detection
kubectl top pods -A --sort-by=cpu
kubectl port-forward -n observability svc/grafana-service 3000:3000

# Investigation
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=100
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Quick Fix
kubectl scale deployment <name> -n <namespace> --replicas=<N>

# Long-term Fix
kubectl apply -f hpa.yaml
kubectl apply -f prometheus-alerts.yaml

# Verification
watch -n 5 'kubectl top pods -n <namespace>'
kubectl get hpa -n <namespace> -w
```

## Key Takeaways

1. ✓ Always check CPU usage trends, not just point-in-time values
2. ✓ Investigate logs and metrics together for full picture
3. ✓ Scale first (quick fix), optimize later (permanent fix)
4. ✓ Implement HPA to automatically handle load spikes
5. ✓ Set up alerts before issues become critical
6. ✓ Document your findings for future reference

## Next Steps

- Review [Scenario 2: Memory Leak Investigation](./02-memory-leak.md)
- Set up comprehensive CPU monitoring dashboard
- Implement automated remediation with Kubernetes operators
- Review application code for optimization opportunities
