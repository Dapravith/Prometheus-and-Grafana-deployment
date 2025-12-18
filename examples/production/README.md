# Production Configuration Examples

This directory contains production-ready configuration examples.

## Persistent Storage

### Prometheus PersistentVolumeClaim

```yaml
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
      storage: 100Gi
  storageClassName: fast-ssd  # Use your storage class
```

Then update `kubernetes/prometheus/deployment.yaml`:

```yaml
volumes:
- name: storage
  persistentVolumeClaim:
    claimName: prometheus-storage
```

### Mimir PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mimir-storage
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Gi  # Mimir needs more space for long-term storage
  storageClassName: standard
```

### Loki PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: loki-storage
  namespace: observability
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi
  storageClassName: standard
```

## Secure Grafana Credentials

### Using External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-admin-credentials
  namespace: observability
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: grafana-admin-credentials
    creationPolicy: Owner
  data:
  - secretKey: admin-user
    remoteRef:
      key: observability/grafana
      property: admin-user
  - secretKey: admin-password
    remoteRef:
      key: observability/grafana
      property: admin-password
```

### Using Sealed Secrets

```bash
# Create a secret
kubectl create secret generic grafana-admin-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml > grafana-secret.yaml

# Seal it
kubeseal -f grafana-secret.yaml -w grafana-sealed-secret.yaml

# Apply sealed secret
kubectl apply -f grafana-sealed-secret.yaml
```

## Resource Adjustments for Production

### High-Load Prometheus

```yaml
resources:
  requests:
    memory: "8Gi"
    cpu: "4000m"
  limits:
    memory: "16Gi"
    cpu: "8000m"
```

### High-Load OpenTelemetry Collector

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "2000m"
  limits:
    memory: "4Gi"
    cpu: "4000m"
```

## Network Policies

### Allow only necessary traffic

```yaml
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
    - podSelector:
        matchLabels:
          app: alloy
    ports:
    - protocol: TCP
      port: 9090
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: mimir
    ports:
    - protocol: TCP
      port: 8080
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443  # For Kubernetes API
```

## TLS/SSL Configuration

### Using cert-manager

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: observability-tls
  namespace: observability
spec:
  secretName: observability-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - grafana.yourdomain.com
  - prometheus.yourdomain.com
  - loki.yourdomain.com
  - mimir.yourdomain.com
```

## Horizontal Pod Autoscaling

### Prometheus HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: prometheus-hpa
  namespace: observability
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: prometheus
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Pod Disruption Budget

### Ensure availability during maintenance

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: prometheus-pdb
  namespace: observability
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: prometheus
```

## Object Storage Configuration

### Mimir with S3

```yaml
blocks_storage:
  backend: s3
  s3:
    endpoint: s3.amazonaws.com
    bucket_name: my-mimir-blocks
    access_key_id: ${AWS_ACCESS_KEY_ID}
    secret_access_key: ${AWS_SECRET_ACCESS_KEY}
  tsdb:
    dir: /data/tsdb
```

### Loki with S3

```yaml
storage_config:
  aws:
    s3: s3://us-east-1/my-loki-bucket
    s3forcepathstyle: true
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
```

## Backup Strategy

### CronJob for Grafana Backup

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: grafana-backup
  namespace: observability
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: curlimages/curl:latest
            command:
            - sh
            - -c
            - |
              curl -u admin:${GRAFANA_PASSWORD} \
                http://grafana-service:3000/api/dashboards/db \
                > /backup/dashboards-$(date +%Y%m%d).json
          restartPolicy: OnFailure
```

## Monitoring the Monitors

### ServiceMonitor for Prometheus

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: prometheus-self
  namespace: observability
spec:
  selector:
    matchLabels:
      app: prometheus
  endpoints:
  - port: web
    interval: 30s
```

## Production Checklist

- [ ] Enable persistent storage for all stateful components
- [ ] Change all default passwords
- [ ] Configure TLS/SSL certificates
- [ ] Set up proper backup strategy
- [ ] Implement network policies
- [ ] Configure resource limits based on load testing
- [ ] Set up horizontal pod autoscaling
- [ ] Implement pod disruption budgets
- [ ] Use external secret management
- [ ] Configure monitoring and alerting for the stack itself
- [ ] Document disaster recovery procedures
- [ ] Set up log rotation policies
- [ ] Configure retention policies based on compliance requirements
