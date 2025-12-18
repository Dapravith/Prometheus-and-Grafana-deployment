# Architecture Diagrams

This directory contains architecture diagrams for the observability stack.

## Available Formats

### 1. Mermaid Diagrams (Rendered on GitHub)

The following Mermaid diagrams are included and will render directly on GitHub:

- `system-architecture.md` - Overall system architecture
- `data-flow.md` - Data flow for metrics, logs, and traces
- `deployment-architecture.md` - Kubernetes deployment structure
- `network-topology.md` - Network connections and ports

### 2. Draw.io XML Sources

Draw.io compatible XML files that can be imported:

- `observability-stack.drawio.xml` - Complete stack architecture
- `component-interactions.drawio.xml` - Component interaction diagram

## How to Use Draw.io Files

1. Go to https://app.diagrams.net/ (draw.io)
2. Click "Open Existing Diagram"
3. Select the `.drawio.xml` file
4. Edit and export as PNG/SVG/PDF

## Creating Screenshots

To create deployment screenshots:

1. Deploy the stack using the HANDS-ON-GUIDE.md
2. Access Grafana: `kubectl port-forward -n observability svc/grafana-service 3000:3000`
3. Open http://localhost:3000 in browser
4. Take screenshots of:
   - Login page
   - Dashboards overview
   - Metrics visualization
   - Datasources configuration
5. Access Prometheus: `kubectl port-forward -n observability svc/prometheus-service 9090:9090`
6. Open http://localhost:9090 in browser
7. Take screenshots of:
   - Targets page
   - Metrics graph
   - Alert rules

## Expected Deployment Output

See `DEPLOYMENT-VERIFICATION.md` for detailed expected outputs at each deployment stage.
