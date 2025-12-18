# Monitoring Scenarios and Use Cases

This directory contains real-world monitoring scenarios, issues, and their solutions.

## Scenarios Overview

1. **High CPU Usage Detection** - Identify and resolve CPU spikes
2. **Memory Leak Investigation** - Track down memory leaks in applications
3. **Failed Deployment Recovery** - Detect and rollback failed deployments
4. **Disk Space Monitoring** - Alert on low disk space
5. **Network Latency Issues** - Identify network bottlenecks
6. **Service Downtime** - Detect and respond to service outages
7. **Slow Query Performance** - Identify database performance issues
8. **Pod Restart Loop** - Debug crash loop back-off issues

## Quick Navigation

- [Scenario 1: High CPU Usage](./01-high-cpu-usage.md)
- [Scenario 2: Memory Leak](./02-memory-leak.md)
- [Scenario 3: Failed Deployment](./03-failed-deployment.md)
- [Scenario 4: Disk Space Alert](./04-disk-space-alert.md)
- [Scenario 5: Network Latency](./05-network-latency.md)
- [Scenario 6: Service Downtime](./06-service-downtime.md)
- [Scenario 7: Slow Queries](./07-slow-queries.md)
- [Scenario 8: Pod Restart Loop](./08-pod-restart-loop.md)

## How to Use These Scenarios

Each scenario follows this structure:

1. **Problem Description** - What's happening
2. **Symptoms** - How to detect the issue
3. **Investigation** - Step-by-step debugging with CLI commands
4. **Root Cause** - What's actually wrong
5. **Solution** - How to fix it
6. **Prevention** - How to avoid it in the future
7. **Monitoring Setup** - Alerts and dashboards to implement

## Prerequisites

Before working through these scenarios, ensure you have:

- Observability stack deployed (Prometheus, Grafana, Loki)
- kubectl access to your cluster
- Basic understanding of Kubernetes concepts
- Access to Grafana dashboards

## Commands Reference

Common commands used across scenarios:

```bash
# Check pod status
kubectl get pods -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# Check pod resource usage
kubectl top pods -n <namespace>

# Port forward to Grafana
kubectl port-forward -n observability svc/grafana-service 3000:3000

# Port forward to Prometheus
kubectl port-forward -n observability svc/prometheus-service 9090:9090

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- <command>

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>
```

## Grafana Access

Default credentials (change in production!):
- URL: http://localhost:3000 (after port-forward)
- Username: admin
- Password: admin

## Prometheus Queries

Common PromQL queries used in scenarios:

```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by pod
container_memory_usage_bytes

# Pod restarts
kube_pod_container_status_restarts_total

# HTTP request rate
rate(http_requests_total[5m])

# HTTP error rate
rate(http_requests_total{status=~"5.."}[5m])

# Disk usage
node_filesystem_avail_bytes / node_filesystem_size_bytes
```

## Contributing New Scenarios

If you encounter a new monitoring scenario:

1. Document the problem clearly
2. Include exact commands and outputs
3. Explain the investigation process
4. Provide the solution and prevention steps
5. Add relevant Grafana dashboard JSON or PromQL queries
6. Submit a PR with your scenario

## Support

For questions or issues with these scenarios:
- Open a GitHub issue
- Check the FAQ.md for common questions
- Review the main README.md for setup instructions
