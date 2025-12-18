# Visual Architecture Guide

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KUBERNETES CLUSTER                                 │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                      Observability Namespace                           │ │
│  │                                                                        │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    MONITORING LAYER                              │ │ │
│  │  │                                                                  │ │ │
│  │  │  ┌─────────────┐         ┌──────────────┐                      │ │ │
│  │  │  │ Prometheus  │◄────────┤   Grafana    │                      │ │ │
│  │  │  │ (HA: 2x)    │ scrape  │  (Portal)    │                      │ │ │
│  │  │  │  Port:9090  │         │  Port:3000   │                      │ │ │
│  │  │  └──────┬──────┘         └───────┬──────┘                      │ │ │
│  │  │         │                        │                              │ │ │
│  │  │         │ remote_write           │ query                       │ │ │
│  │  │         ▼                        ▼                              │ │ │
│  │  │  ┌─────────────┐         ┌──────────────┐                      │ │ │
│  │  │  │   Mimir     │         │     Loki     │                      │ │ │
│  │  │  │ (Long-term) │         │    (Logs)    │                      │ │ │
│  │  │  │  Port:8080  │         │  Port:3100   │                      │ │ │
│  │  │  └─────────────┘         └───────▲──────┘                      │ │ │
│  │  │                                  │                              │ │ │
│  │  └──────────────────────────────────┼──────────────────────────────┘ │ │
│  │                                     │                                │ │
│  │  ┌──────────────────────────────────┼──────────────────────────────┐ │ │
│  │  │                  COLLECTION LAYER                               │ │ │
│  │  │                                  │                               │ │ │
│  │  │  ┌───────────────────────────────┴──────────────────────────┐   │ │ │
│  │  │  │         Grafana Alloy (DaemonSet)                        │   │ │ │
│  │  │  │   • Runs on every node                                   │   │ │ │
│  │  │  │   • Collects node metrics                                │   │ │ │
│  │  │  │   • Forwards logs to Loki                                │   │ │ │
│  │  │  │   • OTLP receiver for traces                             │   │ │ │
│  │  │  └───────────────────────┬──────────────────────────────────┘   │ │ │
│  │  │                          │                                       │ │ │
│  │  │                          │ OTLP                                  │ │ │
│  │  │                          ▼                                       │ │ │
│  │  │  ┌───────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │       OpenTelemetry Collector (HA: 2x)                    │  │ │ │
│  │  │  │   • OTLP gRPC endpoint: 4317                              │  │ │ │
│  │  │  │   • OTLP HTTP endpoint: 4318                              │  │ │ │
│  │  │  │   • Processes metrics, logs, traces                       │  │ │ │
│  │  │  │   • Exports to Prometheus & Loki                          │  │ │ │
│  │  │  └───────────────────────────────────────────────────────────┘  │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                        │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │  │                     INGRESS LAYER                                │ │ │
│  │  │                                                                  │ │ │
│  │  │  grafana.example.com    ──►  Grafana Service (3000)            │ │ │
│  │  │  prometheus.example.com ──►  Prometheus Service (9090)         │ │ │
│  │  │  loki.example.com       ──►  Loki Service (3100)               │ │ │
│  │  │  mimir.example.com      ──►  Mimir Service (8080)              │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     APPLICATION NAMESPACES                             │ │
│  │                                                                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │ │
│  │  │   Pod 1     │  │   Pod 2     │  │   Pod 3     │                  │ │
│  │  │ prometheus. │  │ prometheus. │  │ prometheus. │                  │ │
│  │  │ io/scrape:  │  │ io/scrape:  │  │ io/scrape:  │                  │ │
│  │  │  "true"     │  │  "true"     │  │  "true"     │                  │ │
│  │  │             │  │             │  │             │                  │ │
│  │  │ /metrics ───┼──┼──────────┬──┼──┼──┐                            │ │
│  │  │             │  │          │  │  │  │                            │ │
│  │  └─────────────┘  └──────────┼──┘  └──┼──┘                          │ │
│  │                              │        │                              │ │
│  │                              ▼        ▼                              │ │
│  │                       Prometheus scrapes all pods                     │ │
│  │                       with annotations                                │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

### 1. Metrics Flow

```
┌─────────────┐
│ Application │
│    Pods     │
└──────┬──────┘
       │ expose /metrics endpoint
       │ prometheus.io/scrape: "true"
       ▼
┌─────────────┐     scrape (pull)      ┌──────────────┐
│ Prometheus  │◄──────────────────────►│    Alloy     │
│  (Primary)  │                        │ (DaemonSet)  │
└──────┬──────┘                        └──────────────┘
       │
       │ remote_write (push)
       ▼
┌─────────────┐
│   Mimir     │  Long-term storage
│             │  (Time-series database)
└─────────────┘
       ▲
       │ query
       │
┌─────────────┐
│   Grafana   │  Visualization
│   (Portal)  │
└─────────────┘
```

### 2. Logs Flow

```
┌─────────────┐
│ Application │
│    Pods     │
└──────┬──────┘
       │ stdout/stderr
       │
       ▼
┌─────────────┐    collect (pull)
│   Alloy     │◄────────── Kubernetes
│ (DaemonSet) │            logs API
└──────┬──────┘
       │
       │ push logs
       ▼
┌─────────────┐
│    Loki     │  Log aggregation
│             │  (Log database)
└─────────────┘
       ▲
       │ query (LogQL)
       │
┌─────────────┐
│   Grafana   │  Log exploration
│             │
└─────────────┘
```

### 3. Traces Flow (OpenTelemetry)

```
┌─────────────┐
│ Application │  OTLP SDK
│  with OTLP  │  instrumented
└──────┬──────┘
       │
       │ OTLP/gRPC (4317)
       │ OTLP/HTTP (4318)
       ▼
┌─────────────┐
│   Alloy     │  OTLP receiver
│             │
└──────┬──────┘
       │
       │ forward
       ▼
┌─────────────┐
│   OTel      │  Process and
│ Collector   │  batch traces
│   (HA: 2)   │
└──────┬──────┘
       │
       ├──► Metrics ──► Prometheus
       │
       └──► Logs ────► Loki
```

## Component Interaction Diagram

```
┌────────────────────────────────────────────────────────────┐
│                    User/Developer                          │
└────────────┬───────────────────────────────────────────────┘
             │
             │ HTTP
             ▼
┌────────────────────────────────────────────────────────────┐
│                    Ingress Controller                       │
│  • grafana.example.com                                     │
│  • prometheus.example.com                                  │
└────────────┬───────────────────────────────────────────────┘
             │
             ├───► Grafana ─────────┐
             │                      │
             ├───► Prometheus       │
             │          │           │
             │          │           ▼
             │          │    ┌─────────────┐
             │          │    │   Queries   │
             │          │    └─────────────┘
             │          │           │
             │          ▼           │
             │    ┌─────────┐      │
             │    │  Mimir  │◄─────┘
             │    └─────────┘
             │
             └───► Loki ◄──────────┘
```

## Deployment Architecture

### High Availability Setup

```
┌─────────────────────────────────────────┐
│         Load Balancer / Ingress         │
└────────┬───────────────────┬────────────┘
         │                   │
         ▼                   ▼
┌──────────────┐    ┌──────────────┐
│ Prometheus 1 │    │ Prometheus 2 │  HA: 2 replicas
└──────────────┘    └──────────────┘  Active-Active
         │                   │
         └─────────┬─────────┘
                   │ remote_write
                   ▼
         ┌──────────────┐
         │    Mimir     │  Centralized storage
         └──────────────┘

┌──────────────┐    ┌──────────────┐
│   OTel 1     │    │   OTel 2     │  HA: 2 replicas
└──────────────┘    └──────────────┘  Load balanced
         │                   │
         └─────────┬─────────┘
                   │
                   ├──► Prometheus (metrics)
                   └──► Loki (logs)
```

### DaemonSet Distribution

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Node 1    │  │   Node 2    │  │   Node 3    │
├─────────────┤  ├─────────────┤  ├─────────────┤
│   Alloy     │  │   Alloy     │  │   Alloy     │
│   (Pod)     │  │   (Pod)     │  │   (Pod)     │
└─────────────┘  └─────────────┘  └─────────────┘
      │                │                │
      └────────────────┴────────────────┘
                       │
              Collects from all nodes
                       │
                       ▼
              ┌──────────────┐
              │  Prometheus  │
              │     Loki     │
              └──────────────┘
```

## Network Flow

### Port Mapping

```
Component          │ Port  │ Protocol │ Purpose
───────────────────┼───────┼──────────┼─────────────────
Prometheus         │ 9090  │ HTTP     │ UI & API
Grafana            │ 3000  │ HTTP     │ Web UI
Loki               │ 3100  │ HTTP     │ API
Mimir              │ 8080  │ HTTP     │ API
Alloy              │ 12345 │ HTTP     │ Metrics
OTel Collector     │ 4317  │ gRPC     │ OTLP
OTel Collector     │ 4318  │ HTTP     │ OTLP
OTel Collector     │ 8888  │ HTTP     │ Metrics
OTel Collector     │ 13133 │ HTTP     │ Health
```

### Security Boundaries

```
┌─────────────────────────────────────────────┐
│          Internet / External Users          │
└────────────────┬────────────────────────────┘
                 │ HTTPS (443)
                 ▼
┌─────────────────────────────────────────────┐
│        Ingress Controller (TLS Term)        │
└────────────────┬────────────────────────────┘
                 │ HTTP (internal)
                 ▼
┌─────────────────────────────────────────────┐
│      Observability Namespace (isolated)     │
│  • Network Policies                         │
│  • RBAC                                     │
│  • Service Accounts                         │
└─────────────────────────────────────────────┘
```

## Storage Architecture

```
┌─────────────────┐       ┌─────────────────┐
│   Prometheus    │       │     Mimir       │
│                 │       │                 │
│  Short-term     │──────►│   Long-term     │
│  (15 days)      │ write │   (unlimited)   │
│                 │       │                 │
│  emptyDir/PVC   │       │  emptyDir/PVC   │
└─────────────────┘       │  or Object      │
                          │  Storage (S3)   │
                          └─────────────────┘

┌─────────────────┐
│      Loki       │
│                 │
│  Log storage    │
│  (configurable) │
│                 │
│  emptyDir/PVC   │
│  or Object      │
│  Storage (S3)   │
└─────────────────┘
```

## Scaling Strategy

### Horizontal Scaling

```
Normal Load          │ High Load            │ Peak Load
─────────────────────┼──────────────────────┼─────────────────
Prometheus: 2        │ Prometheus: 2        │ Prometheus: 3
Grafana: 1           │ Grafana: 2           │ Grafana: 3
Loki: 1              │ Loki: 2              │ Loki: 3
Mimir: 1             │ Mimir: 2             │ Mimir: 3
OTel: 2              │ OTel: 3              │ OTel: 5
Alloy: DaemonSet     │ Alloy: DaemonSet     │ Alloy: DaemonSet
```

### Auto-scaling Configuration

```
HPA triggers:
• CPU > 70% → Scale up
• Memory > 80% → Scale up
• CPU < 30% for 5min → Scale down
• Memory < 50% for 5min → Scale down

Limits:
• Min replicas: 2
• Max replicas: 10
• Scale-up rate: 100% (double)
• Scale-down rate: 50% (half)
```

## Monitoring the Monitors

```
┌─────────────────────────────────────┐
│  Observability Stack Self-Monitor   │
└────────────┬────────────────────────┘
             │
             ├──► Prometheus scrapes itself
             ├──► Grafana monitors Prometheus
             ├──► Loki collects own logs
             ├──► Alerts on component failures
             └──► Health checks via CI/CD
```

## Disaster Recovery

```
┌──────────────┐
│    Backup    │
│   Schedule   │
└──────┬───────┘
       │
       ├──► Prometheus data (PVC snapshots)
       ├──► Grafana dashboards (export JSON)
       ├──► Configuration files (git)
       └──► Alert rules (git)
       
┌──────────────┐
│   Recovery   │
│    Process   │
└──────┬───────┘
       │
       ├──► Restore PVCs
       ├──► Apply configurations (kubectl)
       ├──► Import dashboards (Grafana API)
       └──► Verify health checks
```

## Legend

```
┌─────┐
│ Box │  = Component/Service
└─────┘

  ───►   = Data flow direction
  ◄───   = Bidirectional flow
   │     = Connection
   ▼     = Flow downward
```

---

## Quick Reference URLs

- **Grafana UI**: http://localhost:3000
- **Prometheus UI**: http://localhost:9090
- **Prometheus Targets**: http://localhost:9090/targets
- **Loki API**: http://localhost:3100
- **OTel Collector Health**: http://localhost:13133

## Next Steps

1. Review [Hands-On Guide](./HANDS-ON-GUIDE.md) for implementation
2. Check [Scenarios](./scenarios/README.md) for real-world use cases
3. See [Branch Strategy](./BRANCH-STRATEGY.md) for development workflow
