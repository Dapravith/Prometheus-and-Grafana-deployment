# Sample Application with Observability

This example shows how to instrument your application to work with the observability stack.

## Features Demonstrated

- **Prometheus Metrics**: Annotations for automatic scraping
- **OpenTelemetry Integration**: OTLP endpoint configuration
- **Zero-Downtime Deployment**: Rolling update strategy
- **Health Checks**: Liveness and readiness probes

## Prometheus Integration

Add these annotations to your pod template:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

Your application should expose metrics at the `/metrics` endpoint in Prometheus format.

### Example Metrics Endpoint (Go)

```go
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

### Example Metrics Endpoint (Python)

```python
from prometheus_client import Counter, generate_latest, REGISTRY
from flask import Flask, Response

app = Flask(__name__)

requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

@app.route('/metrics')
def metrics():
    return Response(generate_latest(REGISTRY), mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

## OpenTelemetry Integration

Configure your application with these environment variables:

```yaml
env:
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://otel-collector-service.observability.svc.cluster.local:4318"
- name: OTEL_SERVICE_NAME
  value: "your-app-name"
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "environment=production,team=your-team"
```

### Example OpenTelemetry SDK (Node.js)

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME,
  }),
});

const exporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT + '/v1/traces',
});

provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();
```

### Example OpenTelemetry SDK (Python)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource

resource = Resource(attributes={
    "service.name": os.getenv("OTEL_SERVICE_NAME", "my-service")
})

provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") + "/v1/traces"
)
processor = BatchSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
```

## Logging Integration

For structured logging that works with Loki, use JSON format:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "info",
  "service": "sample-app",
  "message": "Request processed",
  "request_id": "abc123",
  "duration_ms": 45
}
```

## Deploy the Sample App

```bash
# Deploy to Kubernetes
kubectl apply -f deployment.yaml

# Verify it's being scraped by Prometheus
kubectl port-forward -n observability svc/prometheus-service 9090:9090
# Visit http://localhost:9090/targets and look for sample-app
```

## Zero-Downtime Deployment Strategy

The example uses:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Create 1 extra pod during update
    maxUnavailable: 0  # Don't terminate pods until new ones are ready
```

This ensures:
1. New version pods are created first
2. Health checks must pass before routing traffic
3. Old version pods are terminated only after new ones are ready
4. Service always has available pods

## Testing

```bash
# Deploy the sample app
kubectl apply -f examples/sample-app/deployment.yaml

# Check if it's running
kubectl get pods -l app=sample-app

# Test the service
kubectl port-forward svc/sample-app-service 8080:8080
curl http://localhost:8080/metrics

# Check in Prometheus
# Port forward: make port-forward-prometheus
# Query: up{app="sample-app"}
```

## Best Practices

1. **Always add Prometheus annotations** for automatic discovery
2. **Use semantic versioning** for image tags
3. **Set resource limits** to prevent resource exhaustion
4. **Implement health checks** for proper rolling updates
5. **Use structured logging** (JSON) for better log analysis
6. **Add meaningful labels** for filtering and aggregation
7. **Include request IDs** for tracing requests across services
8. **Expose business metrics** beyond just technical metrics
