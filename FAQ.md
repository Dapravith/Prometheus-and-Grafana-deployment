# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is this project?

A: This is a complete observability stack that includes Prometheus (metrics), Grafana (visualization), Loki (logs), Mimir (long-term storage), Grafana Alloy (collection agent), and OpenTelemetry Collector. It's designed to be deployed on Kubernetes with zero-downtime and high availability.

### Q: What are the system requirements?

A: Minimum requirements:
- Kubernetes cluster (v1.24+)
- 3 nodes with 4 CPU cores and 16GB RAM each
- 100GB storage (for production with persistent storage)
- kubectl, Terraform (optional), and Ansible (optional)

### Q: Is this production-ready?

A: Yes, but with some considerations:
- Replace `emptyDir` with `PersistentVolumeClaim` for production
- Change default passwords
- Configure proper ingress with TLS/SSL
- Set up backup strategies
- Adjust resource limits based on your workload
- Implement network policies

## Deployment Questions

### Q: Can I deploy this on minikube or kind?

A: Yes! The stack works on local development clusters. Use:
```bash
make deploy
```

### Q: Do I need Terraform to deploy?

A: No, Terraform is optional. You can deploy using:
- kubectl directly: `make deploy`
- Ansible: `make ansible-deploy`
- Terraform: `make terraform-apply`

### Q: How long does deployment take?

A: Typically 5-10 minutes depending on:
- Cluster size
- Internet speed (for pulling images)
- Resource availability

### Q: Can I deploy only some components?

A: Yes, you can deploy components individually:
```bash
kubectl apply -f kubernetes/prometheus/
kubectl apply -f kubernetes/grafana/
# etc.
```

### Q: Which cloud providers are supported?

A: All major providers:
- AWS EKS
- Google GKE
- Azure AKS
- DigitalOcean Kubernetes
- On-premises Kubernetes
- Minikube/kind for development

## Configuration Questions

### Q: How do I change the Grafana admin password?

A: Edit `kubernetes/grafana/deployment.yaml`:
```yaml
env:
- name: GF_SECURITY_ADMIN_PASSWORD
  value: "your-new-password"  # Change this
```

Or use a Kubernetes secret (recommended):
```bash
kubectl create secret generic grafana-secrets \
  --from-literal=admin-password='secure-password' \
  -n observability
```

### Q: How do I change the domain names?

A: Edit `kubernetes/ingress/ingress.yaml` and replace `example.com` with your domain:
```yaml
rules:
- host: grafana.yourdomain.com
- host: prometheus.yourdomain.com
```

### Q: How do I enable persistent storage?

A: Replace `emptyDir` with `persistentVolumeClaim` in deployment files. See DEPLOYMENT.md for examples.

### Q: How do I adjust resource limits?

A: Edit the deployment files and modify:
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Q: Can I use external storage (S3, GCS)?

A: Yes! Mimir and Loki support object storage. Update their configurations to use S3/GCS instead of filesystem.

## Monitoring Questions

### Q: How do I monitor my applications?

A: Add Prometheus annotations to your pods:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

See `examples/sample-app/` for a complete example.

### Q: How do I send logs to Loki?

A: Grafana Alloy automatically collects logs from all pods. For application-specific logging, use structured logs (JSON) and Alloy will forward them to Loki.

### Q: How do I send traces?

A: Configure your application with OpenTelemetry SDK:
```yaml
env:
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://otel-collector-service.observability.svc.cluster.local:4318"
```

### Q: Where can I see my metrics?

A: Access Grafana:
```bash
make port-forward-grafana
# Visit http://localhost:3000
```

### Q: How do I create custom dashboards?

A: In Grafana:
1. Go to Dashboards → New Dashboard
2. Add panels with PromQL queries
3. Save the dashboard

## Troubleshooting Questions

### Q: Pods are not starting, what should I do?

A: Check pod status and logs:
```bash
kubectl get pods -n observability
kubectl describe pod <pod-name> -n observability
kubectl logs <pod-name> -n observability
```

Common issues:
- Insufficient resources
- Image pull errors
- Configuration errors

### Q: Prometheus is not scraping my application

A: Verify:
1. Pod has correct annotations
2. Metrics endpoint is accessible
3. Port matches annotation
4. RBAC permissions are correct
5. Check Prometheus targets: http://localhost:9090/targets

### Q: Grafana cannot connect to Prometheus

A: Check:
1. Services are running: `kubectl get svc -n observability`
2. DNS resolution works inside pods
3. Datasource URL is correct
4. Network policies (if any) allow traffic

### Q: How do I check if everything is working?

A: Run:
```bash
make status
make test-endpoints
```

### Q: Ingress is not working

A: Verify:
1. Ingress controller is installed
2. DNS records point to ingress IP
3. Services are available
4. Check ingress events: `kubectl describe ingress -n observability`

## Performance Questions

### Q: How much storage do I need?

A: Depends on your workload:
- Prometheus: ~1-2GB per million samples per day
- Loki: ~0.5-1GB per GB of logs
- Mimir: For long-term storage, plan accordingly

### Q: How many resources does this use?

A: Default configuration:
- Prometheus: 2Gi RAM, 1 CPU per replica
- Grafana: 512Mi RAM, 250m CPU
- Loki: 1Gi RAM, 500m CPU
- Mimir: 2Gi RAM, 500m CPU
- OpenTelemetry: 1Gi RAM, 500m CPU per replica
- Alloy: 512Mi RAM, 250m CPU per node

Total: ~8-12Gi RAM, 4-6 CPU cores

### Q: How do I scale components?

A: Scale deployments:
```bash
kubectl scale deployment prometheus -n observability --replicas=3
kubectl scale deployment otel-collector -n observability --replicas=3
```

### Q: What's the retention period?

A: Default:
- Prometheus: 15 days
- Loki: Configurable in config
- Mimir: Unlimited (configurable)

## High Availability Questions

### Q: Is this highly available?

A: Yes, for key components:
- Prometheus: 2 replicas
- OpenTelemetry: 2 replicas
- Alloy: DaemonSet (runs on every node)
- Grafana: Can be scaled to multiple replicas

### Q: What happens during pod restarts?

A: Services continue running:
- Rolling updates ensure zero downtime
- Health checks prevent routing to unhealthy pods
- Multiple replicas maintain availability

### Q: How do I test zero-downtime deployment?

A: Update a deployment and watch pods:
```bash
# In one terminal
watch kubectl get pods -n observability

# In another terminal
kubectl set image deployment/prometheus prometheus=prom/prometheus:v2.48.1 -n observability
```

## Security Questions

### Q: Are the containers running as root?

A: No, all containers run as non-root users with security contexts.

### Q: How do I enable TLS/SSL?

A: Install cert-manager and the ingress will automatically get TLS certificates. See DEPLOYMENT.md for details.

### Q: How do I secure Grafana?

A: Options:
1. Change default password
2. Configure OAuth (GitHub, Google, etc.)
3. Use Kubernetes authentication
4. Implement network policies

### Q: Are secrets secure?

A: Use Kubernetes secrets for sensitive data. Consider using:
- External Secrets Operator
- Sealed Secrets
- HashiCorp Vault

## Maintenance Questions

### Q: How do I update components?

A: Update image versions in deployment files and apply:
```bash
kubectl apply -f kubernetes/<component>/deployment.yaml
```

### Q: How do I backup my data?

A: Backup:
- Grafana dashboards and datasources
- Prometheus data (if using persistent storage)
- Configuration files (committed to git)

### Q: How do I rollback a deployment?

A: Use Ansible:
```bash
make ansible-rollback
```

Or kubectl:
```bash
kubectl rollout undo deployment/<name> -n observability
```

### Q: How often should I update?

A: Regularly, but test updates first:
- Security patches: As soon as available
- Minor versions: Monthly
- Major versions: Quarterly (after testing)

## Integration Questions

### Q: Can I use this with existing Prometheus?

A: Yes, configure remote write from your existing Prometheus to Mimir for long-term storage.

### Q: Does this work with service meshes?

A: Yes, it works with Istio, Linkerd, and other service meshes.

### Q: Can I integrate with external systems?

A: Yes, you can:
- Send alerts to external systems
- Export metrics via remote write
- Send logs to external log systems

## Cost Questions

### Q: How much does this cost to run?

A: Depends on your cloud provider:
- AWS EKS: ~$150-300/month for small setup
- GKE: ~$140-280/month
- AKS: ~$140-280/month
- Self-hosted: Hardware/VM costs

### Q: How can I reduce costs?

A: Options:
- Use spot/preemptible instances
- Reduce retention periods
- Scale down non-production environments
- Use object storage (cheaper than block storage)
- Optimize scrape intervals

## Support Questions

### Q: Where can I get help?

A: Resources:
- GitHub Issues for bugs
- GitHub Discussions for questions
- Documentation files (README, DEPLOYMENT, ARCHITECTURE)
- Community Slack/Discord (if available)

### Q: How do I report a bug?

A: Open a GitHub issue with:
- Description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Relevant logs

### Q: Can I contribute?

A: Yes! See CONTRIBUTING.md for guidelines.

---

## Still Have Questions?

Open a GitHub Discussion or Issue, and we'll help you out!
