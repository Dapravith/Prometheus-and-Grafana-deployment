# Scenario 2: Memory Leak Investigation and Resolution

## Problem Description

Your application is experiencing gradual memory growth over time, eventually leading to Out of Memory (OOM) kills and pod restarts. This is a classic memory leak scenario that requires careful investigation.

## Symptoms

- Pods restarting frequently (OOMKilled)
- Gradual increase in memory usage over hours/days
- Application slowdowns before crashes
- "Out of memory" errors in logs
- Increased garbage collection activity (for JVM/Node.js apps)

## Step 1: Detect Memory Issues

### Quick Detection

```bash
# Check for OOMKilled pods
kubectl get pods -A | grep OOMKilled

# Check pod restart counts
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | sort -k2 -rn | head -10

# Monitor current memory usage
kubectl top pods -A --sort-by=memory
```

### Using Grafana

1. Access Grafana: http://localhost:3000
2. Check "Kubernetes / Memory" dashboard
3. Look for:
   - Steadily increasing memory usage
   - Pods near memory limits
   - Frequent pod restarts

### Prometheus Queries

```promql
# Memory usage trend (should be flat or stable)
container_memory_usage_bytes{namespace="production", pod=~"app.*"}

# Memory usage vs limits
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# OOM kills
kube_pod_container_status_terminated_reason{reason="OOMKilled"}

# Restart count
kube_pod_container_status_restarts_total
```

## Step 2: Investigate the Leak

### Check Pod Status

```bash
# Get pod details
kubectl describe pod user-service-xyz -n production

# Look for:
# - Last State: Terminated (Reason: OOMKilled)
# - Exit Code: 137 (OOM killed)

# Example output:
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
  Started:      Mon, 18 Dec 2023 10:00:00 +0000
  Finished:     Mon, 18 Dec 2023 12:30:00 +0000
```

### Analyze Memory Growth Pattern

```bash
# Port forward to Prometheus
kubectl port-forward -n observability svc/prometheus-service 9090:9090
```

Run this query in Prometheus and observe the graph:
```promql
# Memory usage over last 24 hours
container_memory_usage_bytes{pod="user-service-xyz", namespace="production"}[24h]
```

Look for:
- Linear growth = potential leak
- Sawtooth pattern = normal GC behavior
- Sudden spikes = bulk operations

### Check Application Logs

```bash
# Check logs before OOM kill
kubectl logs user-service-xyz -n production --previous

# Look for patterns:
# - Memory allocation errors
# - Large data loads
# - Cache size warnings
# - GC warnings (Java/Node.js)

# Example findings:
kubectl logs user-service-xyz -n production --previous | grep -i "memory\|heap\|gc"
# Output:
# [WARN] Heap usage: 1.8GB / 2GB (90%)
# [ERROR] Cannot allocate memory for large dataset
# [GC] Full GC took 5.2s
```

## Step 3: Identify Root Cause

### Common Memory Leak Causes

1. **Unbounded Caches** - Caches that grow indefinitely
2. **Event Listener Leaks** - Not removing event listeners
3. **Global Variables** - Accumulating data in global scope
4. **Closure Leaks** - References preventing GC
5. **Large Data Processing** - Loading entire datasets into memory

### Application-Specific Investigation

#### For Node.js Applications

```bash
# Get heap snapshot (if your app exposes this)
kubectl exec -it user-service-xyz -n production -- node-heapsnapshot

# Or use built-in memory profiling
kubectl exec -it user-service-xyz -n production -- node --expose-gc --inspect=0.0.0.0:9229 app.js
```

#### For Java Applications

```bash
# Get heap dump
kubectl exec user-service-xyz -n production -- jmap -dump:live,format=b,file=/tmp/heap.bin 1

# Copy heap dump locally
kubectl cp production/user-service-xyz:/tmp/heap.bin ./heap.bin

# Analyze with jhat or Eclipse MAT
jhat heap.bin
```

#### For Python Applications

```bash
# Check memory usage with tracemalloc
kubectl exec -it user-service-xyz -n production -- python3 -c "
import tracemalloc
import linecache
import os

tracemalloc.start()

# Your app code here

snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics('lineno')

for stat in top_stats[:10]:
    print(stat)
"
```

### Example: Found the Leak

```javascript
// BAD: Memory leak - cache grows unbounded
const cache = {};

app.get('/user/:id', (req, res) => {
  const userId = req.params.id;
  
  // This cache NEVER clears old entries!
  if (!cache[userId]) {
    cache[userId] = fetchUserData(userId);
  }
  
  res.json(cache[userId]);
});

// Over time, cache contains ALL users ever requested
// With millions of users = OOM
```

## Step 4: Implement Solution

### Solution 1: Fix the Code

```javascript
// GOOD: Bounded cache with LRU eviction
const LRU = require('lru-cache');

const cache = new LRU({
  max: 1000,      // Max 1000 items
  maxAge: 1000 * 60 * 5  // 5 minutes TTL
});

app.get('/user/:id', (req, res) => {
  const userId = req.params.id;
  
  let userData = cache.get(userId);
  if (!userData) {
    userData = fetchUserData(userId);
    cache.set(userId, userData);
  }
  
  res.json(userData);
});
```

### Solution 2: Increase Memory Limits (Temporary)

```bash
# Edit deployment
kubectl edit deployment user-service -n production
```

```yaml
resources:
  requests:
    memory: "512Mi"
  limits:
    memory: "2Gi"  # Increased from 1Gi
```

### Solution 3: Add Memory Management

```javascript
// Add explicit cleanup
setInterval(() => {
  if (global.gc) {
    global.gc();  // Force garbage collection
  }
}, 60000);  // Every minute

// Add memory monitoring
setInterval(() => {
  const usage = process.memoryUsage();
  console.log({
    rss: `${Math.round(usage.rss / 1024 / 1024)}MB`,
    heapTotal: `${Math.round(usage.heapTotal / 1024 / 1024)}MB`,
    heapUsed: `${Math.round(usage.heapUsed / 1024 / 1024)}MB`,
    external: `${Math.round(usage.external / 1024 / 1024)}MB`,
  });
  
  // Alert if usage too high
  if (usage.heapUsed / usage.heapTotal > 0.9) {
    console.error('WARNING: Memory usage at 90%');
  }
}, 30000);
```

### Solution 4: Implement Stream Processing

```javascript
// BAD: Load everything into memory
const data = await db.query('SELECT * FROM large_table');
const processed = data.map(transform);
res.json(processed);

// GOOD: Stream processing
const stream = db.stream('SELECT * FROM large_table');
stream
  .pipe(transformStream)
  .pipe(jsonStream)
  .pipe(res);
```

## Step 5: Deploy and Verify

```bash
# Deploy the fix
kubectl set image deployment/user-service user-service=user-service:v2.1.0 -n production

# Watch rollout
kubectl rollout status deployment/user-service -n production

# Monitor memory usage
watch -n 10 'kubectl top pod -n production | grep user-service'

# Check for restarts (should stop)
watch -n 5 'kubectl get pods -n production | grep user-service'
```

### Verify in Grafana

Monitor these for 24-48 hours:

1. **Memory usage should stabilize**
   ```promql
   container_memory_usage_bytes{pod=~"user-service.*"}
   ```

2. **No more OOM kills**
   ```promql
   increase(kube_pod_container_status_terminated_reason{reason="OOMKilled"}[1h])
   ```

3. **Restart count should remain constant**
   ```promql
   kube_pod_container_status_restarts_total{pod=~"user-service.*"}
   ```

## Step 6: Prevention

### Set Up Memory Alerts

```yaml
# memory-alerts.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: memory-alerts
  namespace: observability
data:
  alerts.yml: |
    groups:
    - name: memory_alerts
      rules:
      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.pod }}"
          description: "{{ $labels.pod }} is using {{ $value | humanizePercentage }} of memory limit"
      
      - alert: MemoryLeakSuspected
        expr: rate(container_memory_usage_bytes[1h]) > 1048576  # 1MB/hour growth
        for: 6h
        labels:
          severity: warning
        annotations:
          summary: "Possible memory leak in {{ $labels.pod }}"
          description: "Memory usage growing steadily for {{ $labels.pod }}"
      
      - alert: PodOOMKilled
        expr: increase(kube_pod_container_status_terminated_reason{reason="OOMKilled"}[5m]) > 0
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} was OOMKilled"
          description: "Immediate investigation required"
```

### Implement Proactive Monitoring

```yaml
# memory-dashboard.json (Grafana)
{
  "panels": [
    {
      "title": "Memory Usage vs Limit",
      "targets": [
        {
          "expr": "container_memory_usage_bytes / container_spec_memory_limit_bytes * 100"
        }
      ]
    },
    {
      "title": "Memory Growth Rate",
      "targets": [
        {
          "expr": "rate(container_memory_usage_bytes[1h])"
        }
      ]
    },
    {
      "title": "OOM Kills (Last 24h)",
      "targets": [
        {
          "expr": "increase(kube_pod_container_status_terminated_reason{reason=\"OOMKilled\"}[24h])"
        }
      ]
    }
  ]
}
```

### Add Memory Profiling to Application

```javascript
// app.js - Add health endpoint with memory info
app.get('/health/memory', (req, res) => {
  const usage = process.memoryUsage();
  res.json({
    status: 'ok',
    memory: {
      rss: usage.rss,
      heapTotal: usage.heapTotal,
      heapUsed: usage.heapUsed,
      external: usage.external,
      percentUsed: (usage.heapUsed / usage.heapTotal * 100).toFixed(2)
    }
  });
});
```

## Commands Summary

```bash
# Detection
kubectl get pods -A | grep OOMKilled
kubectl top pods -A --sort-by=memory
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# Investigation
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous
kubectl exec -it <pod> -n <namespace> -- /bin/sh

# Fix and Deploy
kubectl set image deployment/<name> <container>=<image>:<tag> -n <namespace>
kubectl rollout status deployment/<name> -n <namespace>

# Verification
watch -n 10 'kubectl top pod -n <namespace>'
kubectl apply -f memory-alerts.yaml
```

## Key Takeaways

1. ✓ OOMKilled + Exit Code 137 = Memory issue
2. ✓ Monitor memory growth rate, not just current usage
3. ✓ Use bounded caches and proper data structures
4. ✓ Implement streaming for large datasets
5. ✓ Set up alerts BEFORE memory issues occur
6. ✓ Profile your application under realistic load

## Next Steps

- Review [Scenario 3: Failed Deployment Recovery](./03-failed-deployment.md)
- Implement memory profiling in all services
- Set up automated heap dump collection on OOM
- Create runbook for memory leak investigation
