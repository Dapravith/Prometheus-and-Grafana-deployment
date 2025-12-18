# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Kubernetes Cluster                          │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Observability Namespace                    │  │
│  │                                                                │  │
│  │  ┌──────────────┐      ┌──────────────┐                      │  │
│  │  │  Prometheus  │◄─────┤   Grafana    │                      │  │
│  │  │  (Replica: 2)│      │  (Replica: 1)│                      │  │
│  │  └──────┬───────┘      └──────┬───────┘                      │  │
│  │         │                     │                               │  │
│  │         │ Remote Write        │ Queries                       │  │
│  │         ▼                     ▼                               │  │
│  │  ┌──────────────┐      ┌──────────────┐                      │  │
│  │  │    Mimir     │      │     Loki     │                      │  │
│  │  │  (Long-term  │      │  (Logs)      │                      │  │
│  │  │   Storage)   │      │  (Replica: 1)│                      │  │
│  │  └──────────────┘      └──────▲───────┘                      │  │
│  │                               │                               │  │
│  │                               │ Logs                          │  │
│  │                               │                               │  │
│  │  ┌──────────────────────────┴─────────────────────────────┐ │  │
│  │  │              Grafana Alloy (DaemonSet)                  │ │  │
│  │  │         (Metrics & Logs Collection Agent)               │ │  │
│  │  └──────────────────────────┬─────────────────────────────┘ │  │
│  │                             │                                │  │
│  │                             │ OTLP Protocol                  │  │
│  │                             ▼                                │  │
│  │  ┌───────────────────────────────────────────────────────┐  │  │
│  │  │         OpenTelemetry Collector (Replica: 2)          │  │  │
│  │  │    (Traces, Metrics, Logs - Universal Collector)      │  │  │
│  │  └───────────────────────────────────────────────────────┘  │  │
│  │                                                                │  │
│  │  ┌───────────────────────────────────────────────────────┐  │  │
│  │  │                    Ingress Controller                   │  │  │
│  │  │  - grafana.example.com → Grafana Service               │  │  │
│  │  │  - prometheus.example.com → Prometheus Service         │  │  │
│  │  │  - loki.example.com → Loki Service                     │  │  │
│  │  │  - mimir.example.com → Mimir Service                   │  │  │
│  │  └───────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                   Application Pods                            │  │
│  │   (Instrumented with Prometheus annotations & OTLP SDK)       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Prometheus (Metrics Collection)
- **Replicas**: 2 (High Availability)
- **Purpose**: Time-series metrics collection and short-term storage
- **Features**:
  - Kubernetes service discovery
  - Automatic scraping of annotated pods
  - Remote write to Mimir for long-term storage
  - Built-in alerting capabilities

### 2. Grafana (Visualization)
- **Replicas**: 1
- **Purpose**: Dashboarding and visualization platform
- **Features**:
  - Pre-configured datasources (Prometheus, Loki, Mimir)
  - Dashboard provisioning
  - Multi-datasource support
  - User authentication

### 3. Grafana Loki (Log Aggregation)
- **Replicas**: 1
- **Purpose**: Log aggregation and querying
- **Features**:
  - Label-based log indexing
  - LogQL query language
  - Efficient log storage
  - Integration with Grafana

### 4. Grafana Alloy (Data Collection Agent)
- **Deployment**: DaemonSet (runs on every node)
- **Purpose**: Modern telemetry collection agent
- **Features**:
  - Metrics scraping from Kubernetes pods
  - Log collection and forwarding
  - OTLP receiver for traces
  - Dynamic configuration
  - Low resource footprint

### 5. Mimir (Long-term Metrics Storage)
- **Replicas**: 1
- **Purpose**: Long-term metrics storage and querying
- **Features**:
  - Horizontal scalability
  - Multi-tenancy support
  - PromQL compatibility
  - Efficient data compression
  - Long retention periods

### 6. OpenTelemetry Collector (Universal Telemetry)
- **Replicas**: 2 (High Availability)
- **Purpose**: Vendor-agnostic telemetry collection
- **Features**:
  - OTLP protocol support (gRPC and HTTP)
  - Multiple receivers (OTLP, Prometheus)
  - Flexible exporters (Prometheus, Loki)
  - Trace, metric, and log processing
  - Batching and sampling

## Data Flow

### Metrics Flow
```
Application Pods → Prometheus (scrape) → Mimir (remote_write)
                                       ↓
                                    Grafana (query)
```

### Logs Flow
```
Application Pods → Alloy (collect) → Loki (store)
                                    ↓
                                 Grafana (query)
```

### Traces Flow
```
Application (OTLP SDK) → OpenTelemetry Collector → [Future: Tempo]
                                                  ↓
                                              Grafana (query)
```

### OpenTelemetry Integration
```
Instrumented Apps → Alloy (OTLP receiver) → Metrics: Prometheus
                                           → Logs: Loki
                                           → Traces: [Future: Tempo]
```

## Network Architecture

### Service Discovery
- **Prometheus**: Automatically discovers Kubernetes endpoints, services, and pods
- **Alloy**: Uses Kubernetes API for dynamic service discovery
- **OpenTelemetry**: Receives telemetry via OTLP protocol

### Service Communication
- All services communicate within the `observability` namespace
- DNS-based service discovery: `<service-name>.observability.svc.cluster.local`
- Internal ClusterIP services for inter-component communication

### External Access
- **Ingress Controller**: Routes external traffic to internal services
- **TLS/SSL**: Configurable via cert-manager annotations
- **Domains**: Customizable in ingress configuration

## High Availability Strategy

### Zero-Downtime Deployment
1. **Rolling Updates**: New pods are created before old ones are terminated
2. **Health Checks**: Readiness and liveness probes ensure pod health
3. **Replica Distribution**: Multiple replicas spread across nodes
4. **Service Load Balancing**: Kubernetes service distributes traffic

### Fault Tolerance
- **Multiple Prometheus replicas**: Continue collecting if one fails
- **OpenTelemetry HA**: Two collectors ensure telemetry ingestion
- **DaemonSet for Alloy**: Runs on every node for resilience
- **Resource limits**: Prevent resource exhaustion

## Security Architecture

### Pod Security
- Non-root containers (UID > 0)
- Read-only root filesystems where possible
- Security contexts with least privilege
- Resource limits to prevent DoS

### Network Security
- Namespace isolation
- Service account RBAC
- ClusterRole with minimal permissions
- Optional: NetworkPolicies for pod-to-pod communication

### Access Control
- RBAC for Kubernetes API access
- Grafana authentication
- Service accounts with specific permissions
- Ingress authentication (configurable)

## Scalability

### Horizontal Scaling
- **Prometheus**: Scale replicas for higher ingestion rate
- **OpenTelemetry**: Add replicas for more telemetry load
- **Mimir**: Scale components independently (ingester, compactor, etc.)

### Vertical Scaling
- Adjust resource requests/limits based on workload
- Monitor resource usage via Grafana dashboards
- Use Kubernetes metrics server for autoscaling

## Storage Strategy

### Short-term Storage (Prometheus)
- **Retention**: 15 days
- **Purpose**: Recent metrics for alerting and dashboards
- **Storage**: EmptyDir (ephemeral) or PersistentVolume

### Long-term Storage (Mimir)
- **Retention**: Configurable (default: unlimited)
- **Purpose**: Historical metrics for trending and analysis
- **Storage**: Filesystem or object storage (S3, GCS, Azure Blob)

### Log Storage (Loki)
- **Retention**: Configurable
- **Purpose**: Log aggregation and querying
- **Storage**: Filesystem or object storage

## Monitoring the Monitors

### Self-Monitoring
- Prometheus scrapes itself and other components
- OpenTelemetry exports its own metrics
- Grafana dashboards for observability stack health

### Key Metrics to Watch
- Prometheus ingestion rate
- Loki ingestion rate
- OpenTelemetry collector queue size
- Mimir storage usage
- Pod resource utilization
