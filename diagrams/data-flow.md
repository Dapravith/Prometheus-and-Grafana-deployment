# Data Flow Diagrams

## Metrics Flow

```mermaid
flowchart TD
    subgraph "Application Layer"
        A1[Application Pod 1]
        A2[Application Pod 2]
        A3[Application Pod 3]
    end

    subgraph "Collection"
        Prometheus[📊 Prometheus]
        Alloy[🔄 Alloy DaemonSet]
    end

    subgraph "Storage"
        Mimir[🗄️ Mimir<br/>Long-term Storage]
    end

    subgraph "Visualization"
        Grafana[📈 Grafana]
    end

    A1 -->|expose /metrics| Prometheus
    A2 -->|expose /metrics| Prometheus
    A3 -->|expose /metrics| Prometheus

    A1 -.->|host metrics| Alloy
    A2 -.->|host metrics| Alloy
    A3 -.->|host metrics| Alloy

    Alloy -->|forward| Prometheus
    Prometheus -->|remote_write| Mimir
    
    Prometheus <-->|query| Grafana
    Mimir <-->|query<br/>long-term data| Grafana

    style Prometheus fill:#ff6b6b
    style Mimir fill:#f38181
    style Grafana fill:#4ecdc4
    style Alloy fill:#ffd93d
```

## Logs Flow

```mermaid
flowchart TD
    subgraph "Application Layer"
        A1[Application Pod 1]
        A2[Application Pod 2]
        A3[Application Pod 3]
    end

    subgraph "Kubernetes"
        K8s[☸️ Kubernetes<br/>Logs API<br/>stdout/stderr]
    end

    subgraph "Collection"
        Alloy[🔄 Alloy DaemonSet<br/>on each node]
    end

    subgraph "Storage"
        Loki[📝 Loki<br/>Log Database]
    end

    subgraph "Visualization"
        Grafana[📈 Grafana<br/>Explore]
    end

    A1 -->|stdout/stderr| K8s
    A2 -->|stdout/stderr| K8s
    A3 -->|stdout/stderr| K8s

    K8s -->|read logs| Alloy
    Alloy -->|push logs| Loki
    Loki <-->|query<br/>LogQL| Grafana

    style Loki fill:#95e1d3
    style Grafana fill:#4ecdc4
    style Alloy fill:#ffd93d
    style K8s fill:#326ce5
```

## Traces Flow (OpenTelemetry)

```mermaid
flowchart TD
    subgraph "Instrumented Applications"
        App[Application with<br/>OTLP SDK]
    end

    subgraph "Collection - Alloy"
        Alloy[🔄 Alloy<br/>OTLP Receiver<br/>gRPC: 4317<br/>HTTP: 4318]
    end

    subgraph "Collection - OTel"
        OTel[🔭 OpenTelemetry<br/>Collector<br/>Process & Batch]
    end

    subgraph "Backends"
        Prometheus[📊 Prometheus<br/>Metrics]
        Loki[📝 Loki<br/>Logs]
        Tempo[🎯 Tempo<br/>Traces<br/>future]
    end

    subgraph "Visualization"
        Grafana[📈 Grafana]
    end

    App -->|OTLP gRPC/HTTP| Alloy
    Alloy -->|forward| OTel
    
    OTel -->|metrics| Prometheus
    OTel -->|logs| Loki
    OTel -.->|traces| Tempo

    Prometheus <--> Grafana
    Loki <--> Grafana
    Tempo -.-> Grafana

    style App fill:#ffeaa7
    style Alloy fill:#ffd93d
    style OTel fill:#6bcf7f
    style Prometheus fill:#ff6b6b
    style Loki fill:#95e1d3
    style Tempo fill:#dfe6e9
    style Grafana fill:#4ecdc4
```

## Complete Data Pipeline

```mermaid
graph TB
    subgraph "Data Sources"
        Apps[📱 Applications]
        Infra[🖥️ Infrastructure]
        K8s[☸️ Kubernetes]
    end

    subgraph "Collection Layer"
        Alloy[🔄 Alloy<br/>DaemonSet]
        OTel[🔭 OTel<br/>Collector]
        Prom[📊 Prometheus<br/>Scraper]
    end

    subgraph "Processing"
        Filter[🔍 Filter &<br/>Transform]
        Batch[📦 Batch &<br/>Buffer]
    end

    subgraph "Storage Layer"
        PromStore[📊 Prometheus<br/>15 days]
        MimirStore[🗄️ Mimir<br/>Long-term]
        LokiStore[📝 Loki<br/>Logs]
    end

    subgraph "Query & Visualization"
        Grafana[📈 Grafana<br/>Dashboards]
        Alerts[🚨 Alerts]
    end

    Apps -->|Metrics| Prom
    Apps -->|Logs| Alloy
    Apps -->|Traces| OTel
    
    Infra -->|Metrics| Alloy
    K8s -->|Metrics| Prom
    K8s -->|Logs| Alloy

    Alloy --> Filter
    OTel --> Filter
    Prom --> PromStore

    Filter --> Batch
    Batch --> PromStore
    Batch --> LokiStore

    PromStore -->|remote_write| MimirStore
    PromStore --> Grafana
    MimirStore --> Grafana
    LokiStore --> Grafana

    Grafana --> Alerts

    style Apps fill:#ffeaa7
    style Alloy fill:#ffd93d
    style OTel fill:#6bcf7f
    style Prom fill:#ff6b6b
    style PromStore fill:#ff6b6b
    style MimirStore fill:#f38181
    style LokiStore fill:#95e1d3
    style Grafana fill:#4ecdc4
    style Alerts fill:#fd79a8
```

## Data Retention Strategy

```mermaid
timeline
    title Data Retention Strategy
    section Short-term (Prometheus)
        Day 1-15 : All metrics
                 : High granularity
                 : Fast queries
    section Long-term (Mimir)
        Day 16-365 : Aggregated metrics
                   : Reduced granularity
                   : Historical analysis
    section Archive
        Year 1+ : Cold storage
               : Compliance
               : Auditing
```

## Query Path

```mermaid
sequenceDiagram
    participant User
    participant Grafana
    participant Prometheus
    participant Mimir
    participant Loki

    User->>Grafana: Query last 24h metrics
    
    alt Recent data (< 15 days)
        Grafana->>Prometheus: PromQL query
        Prometheus->>Grafana: Return recent data
    else Historical data (> 15 days)
        Grafana->>Mimir: PromQL query
        Mimir->>Grafana: Return historical data
    end

    User->>Grafana: Query logs
    Grafana->>Loki: LogQL query
    Loki->>Grafana: Return logs

    Grafana->>User: Display results
```

## Metrics Cardinality

```mermaid
graph LR
    subgraph "Low Cardinality"
        L1[Node metrics<br/>~100 series]
        L2[Service metrics<br/>~500 series]
    end

    subgraph "Medium Cardinality"
        M1[Pod metrics<br/>~5K series]
        M2[Container metrics<br/>~10K series]
    end

    subgraph "High Cardinality"
        H1[Application metrics<br/>~100K series]
        H2[Custom metrics<br/>~1M series]
    end

    L1 & L2 --> Prometheus
    M1 & M2 --> Prometheus
    H1 & H2 --> Prometheus

    Prometheus -->|All data| Mimir

    style L1 fill:#55efc4
    style L2 fill:#55efc4
    style M1 fill:#ffeaa7
    style M2 fill:#ffeaa7
    style H1 fill:#ff7675
    style H2 fill:#ff7675
```

## Legend

| Symbol | Component | Purpose |
|--------|-----------|---------|
| 📊 | Prometheus | Metrics collection & short-term storage |
| 🗄️ | Mimir | Long-term metrics storage |
| 📝 | Loki | Log aggregation & storage |
| 🔄 | Alloy | Collection agent (DaemonSet) |
| 🔭 | OpenTelemetry | Universal telemetry collector |
| 📈 | Grafana | Visualization & dashboards |
| ☸️ | Kubernetes | Container orchestration |
| 🚨 | Alerts | Alerting system |

## Data Flow Summary

1. **Metrics**: Apps → Prometheus → Mimir → Grafana
2. **Logs**: Apps → K8s → Alloy → Loki → Grafana
3. **Traces**: Apps → Alloy/OTel → (Future: Tempo) → Grafana
