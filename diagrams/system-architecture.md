# System Architecture Diagram

## Overall Architecture

```mermaid
graph TB
    subgraph "External Access"
        User[👤 User/Developer]
        Internet[🌐 Internet]
    end

    subgraph "Ingress Layer"
        Ingress[🚪 Ingress Controller<br/>NGINX]
    end

    subgraph "Observability Namespace"
        subgraph "Monitoring Components"
            Prometheus[📊 Prometheus<br/>HA: 2 replicas<br/>Port: 9090]
            Grafana[📈 Grafana<br/>Visualization<br/>Port: 3000]
            Mimir[🗄️ Mimir<br/>Long-term Storage<br/>Port: 8080]
            Loki[📝 Loki<br/>Log Aggregation<br/>Port: 3100]
        end

        subgraph "Collection Layer"
            Alloy[🔄 Grafana Alloy<br/>DaemonSet<br/>Port: 12345]
            OTel[🔭 OpenTelemetry<br/>HA: 2 replicas<br/>Ports: 4317, 4318]
        end
    end

    subgraph "Application Namespace"
        App1[📦 App Pod 1<br/>prometheus.io/scrape: true]
        App2[📦 App Pod 2<br/>prometheus.io/scrape: true]
        App3[📦 App Pod 3<br/>prometheus.io/scrape: true]
    end

    %% User connections
    User -->|HTTPS| Internet
    Internet -->|TLS Termination| Ingress

    %% Ingress routing
    Ingress -->|grafana.example.com| Grafana
    Ingress -->|prometheus.example.com| Prometheus
    Ingress -->|loki.example.com| Loki
    Ingress -->|mimir.example.com| Mimir

    %% Monitoring flow
    Prometheus -->|Query| Grafana
    Loki -->|Query| Grafana
    Mimir -->|Query| Grafana
    Prometheus -->|Remote Write| Mimir

    %% Collection flow
    App1 -.->|/metrics| Prometheus
    App2 -.->|/metrics| Prometheus
    App3 -.->|/metrics| Prometheus

    App1 -.->|Logs| Alloy
    App2 -.->|Logs| Alloy
    App3 -.->|Logs| Alloy

    App1 -->|OTLP| OTel
    App2 -->|OTLP| OTel
    App3 -->|OTLP| OTel

    Alloy -->|Push Logs| Loki
    Alloy -->|Metrics| Prometheus
    OTel -->|Metrics| Prometheus
    OTel -->|Logs| Loki

    style Prometheus fill:#ff6b6b
    style Grafana fill:#4ecdc4
    style Loki fill:#95e1d3
    style Mimir fill:#f38181
    style Alloy fill:#ffd93d
    style OTel fill:#6bcf7f
    style Ingress fill:#a8dadc
```

## High Availability Architecture

```mermaid
graph LR
    subgraph "Load Balancing"
        LB[⚖️ Load Balancer]
    end

    subgraph "Prometheus HA"
        P1[📊 Prometheus-1<br/>Active]
        P2[📊 Prometheus-2<br/>Active]
    end

    subgraph "OpenTelemetry HA"
        O1[🔭 OTel-1]
        O2[🔭 OTel-2]
    end

    subgraph "Alloy DaemonSet"
        A1[🔄 Alloy Node-1]
        A2[🔄 Alloy Node-2]
        A3[🔄 Alloy Node-3]
    end

    subgraph "Storage Layer"
        Mimir[🗄️ Mimir<br/>Centralized]
        Loki[📝 Loki<br/>Centralized]
    end

    LB --> P1
    LB --> P2
    P1 --> Mimir
    P2 --> Mimir

    LB --> O1
    LB --> O2
    O1 --> Loki
    O2 --> Loki

    A1 --> P1
    A2 --> P2
    A3 --> P1

    style P1 fill:#ff6b6b
    style P2 fill:#ff6b6b
    style O1 fill:#6bcf7f
    style O2 fill:#6bcf7f
    style A1 fill:#ffd93d
    style A2 fill:#ffd93d
    style A3 fill:#ffd93d
    style Mimir fill:#f38181
    style Loki fill:#95e1d3
```

## Deployment Strategy - Zero Downtime

```mermaid
sequenceDiagram
    participant User
    participant LB as Load Balancer
    participant Old as Old Version Pods
    participant New as New Version Pods
    participant K8s as Kubernetes

    Note over K8s: RollingUpdate Strategy<br/>maxUnavailable: 0<br/>maxSurge: 1

    K8s->>New: Create new pod (v2)
    New->>New: Starting...
    New->>New: Health checks running
    New->>K8s: Ready ✓

    User->>LB: Request
    LB->>Old: Traffic (100%)
    Old->>User: Response

    K8s->>LB: Add new pod to service
    
    User->>LB: Request
    LB->>Old: Traffic (50%)
    LB->>New: Traffic (50%)
    
    K8s->>New: Create another new pod (v2)
    New->>K8s: Ready ✓
    
    K8s->>Old: Terminate old pod (v1)
    Old->>Old: Graceful shutdown
    
    User->>LB: Request
    LB->>New: Traffic (100%)
    New->>User: Response

    Note over K8s: Deployment Complete<br/>Zero Downtime ✓
```

## Legend

- 📊 Prometheus - Metrics collection
- 📈 Grafana - Visualization
- 🗄️ Mimir - Long-term storage
- 📝 Loki - Log aggregation
- 🔄 Alloy - Collection agent
- 🔭 OpenTelemetry - Universal collector
- 🚪 Ingress - External access
- 📦 Application pods
- ⚖️ Load balancer

## Quick Reference

| Component | Port | Purpose |
|-----------|------|---------|
| Prometheus | 9090 | Metrics UI & API |
| Grafana | 3000 | Web UI |
| Loki | 3100 | Log API |
| Mimir | 8080 | Storage API |
| Alloy | 12345 | Agent metrics |
| OTel gRPC | 4317 | OTLP receiver |
| OTel HTTP | 4318 | OTLP receiver |
| OTel Health | 13133 | Health checks |
