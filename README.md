# Observability Stack Deployment

A comprehensive observability solution built with **Prometheus**, **Grafana**, **Grafana Loki**, **Grafana Alloy**, **Mimir**, and **OpenTelemetry**, deployed on Kubernetes with zero-downtime using Terraform and Ansible.

## 🏗️ Architecture Overview

This project deploys a complete observability stack with the following components:

- **Prometheus** - Metrics collection and storage with high availability (2 replicas)
- **Grafana** - Visualization and dashboarding platform
- **Grafana Loki** - Log aggregation system
- **Grafana Alloy** - Modern telemetry collection agent (replaces Grafana Agent)
- **Mimir** - Long-term metrics storage and querying
- **OpenTelemetry Collector** - Vendor-agnostic telemetry collection with 2 replicas for HA

### Key Features

✅ **Zero-Downtime Deployment** - Rolling updates with proper health checks  
✅ **High Availability** - Multiple replicas for critical components  
✅ **Auto-Discovery** - Kubernetes service discovery for automatic monitoring  
✅ **Horizontal Scalability** - ReplicaSets ensure scalability and fault tolerance  
✅ **Ingress Support** - External access via Kubernetes Ingress  
✅ **Infrastructure as Code** - Managed with Terraform  
✅ **Configuration Management** - Automated deployment with Ansible  
✅ **Long-term Storage** - Mimir for metrics retention beyond Prometheus  
✅ **Unified Observability** - Metrics, logs, and traces in one place

## 📋 Prerequisites

Before deploying, ensure you have:

- **Kubernetes cluster** (v1.24+) - minikube, kind, EKS, GKE, AKS, etc.
- **kubectl** (v1.24+) - Kubernetes CLI
- **Terraform** (v1.5+) - Infrastructure as Code
- **Ansible** (v2.10+) - Configuration management
- **Helm** (v3.0+) - Package manager for Kubernetes (optional)
- **make** - Build automation tool

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Dapravith/Prometheus-and-Grafana-deployment.git
cd Prometheus-and-Grafana-deployment
```

### 2. Initialize the Project

```bash
make init
```

This will:
- Initialize Terraform
- Install required Ansible collections

### 3. Deploy the Stack

#### Option A: Deploy with kubectl (Simple)

```bash
make deploy
```

#### Option B: Deploy with Terraform

```bash
make terraform-init
make terraform-plan
make terraform-apply
```

#### Option C: Deploy with Ansible (Recommended for Production)

```bash
make ansible-deploy
```

### 4. Verify Deployment

```bash
make status
```

### 5. Access Services

#### Port Forwarding (Local Access)

```bash
# Access Grafana at http://localhost:3000
make port-forward-grafana

# Access Prometheus at http://localhost:9090
make port-forward-prometheus
```

Default Grafana credentials (for development only):
- **Username**: `admin`
- **Password**: `admin`

> ⚠️ **IMPORTANT**: Change the default password immediately in production! Edit `kubernetes/grafana/deployment.yaml` and update the `grafana-admin-credentials` secret.

#### Via Ingress (Production)

Update the domain in `kubernetes/ingress/ingress.yaml` and access:
- Grafana: `http://grafana.your-domain.com`
- Prometheus: `http://prometheus.your-domain.com`
- Loki: `http://loki.your-domain.com`
- Mimir: `http://mimir.your-domain.com`

## 📁 Project Structure

```
.
├── terraform/                  # Terraform infrastructure code
│   ├── main.tf                # Provider and backend configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   └── namespace.tf           # Kubernetes namespace resource
│
├── kubernetes/                 # Kubernetes manifests
│   ├── namespaces/            # Namespace definitions
│   ├── prometheus/            # Prometheus deployment
│   ├── grafana/               # Grafana deployment
│   ├── loki/                  # Loki deployment
│   ├── mimir/                 # Mimir deployment
│   ├── alloy/                 # Grafana Alloy deployment
│   ├── opentelemetry/         # OpenTelemetry Collector deployment
│   └── ingress/               # Ingress configuration
│
├── ansible/                    # Ansible automation
│   ├── inventory/             # Inventory files
│   ├── playbooks/             # Deployment playbooks
│   │   ├── deploy.yml         # Main deployment playbook
│   │   └── rollback.yml       # Rollback playbook
│   └── roles/                 # Ansible roles (future)
│
├── Makefile                    # Common operations
└── README.md                   # This file
```

## 🔧 Configuration

### Prometheus Configuration

Edit `kubernetes/prometheus/configmap.yaml` to customize:
- Scrape intervals
- Scrape targets
- Alerting rules
- Remote write configuration

### Grafana Datasources

Datasources are automatically configured:
- **Prometheus** - Default datasource for metrics
- **Loki** - Log datasource
- **Mimir** - Long-term metrics storage

### OpenTelemetry Collector

Edit `kubernetes/opentelemetry/deployment.yaml` to configure:
- Receivers (OTLP, Prometheus)
- Processors (batch, resource)
- Exporters (Prometheus, Loki)

## 🔄 Zero-Downtime Deployment Strategy

All deployments use **RollingUpdate** strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

This ensures:
- New pods are created before old ones are terminated
- Services remain available during updates
- Health checks validate new pods before traffic is routed

### Deployment Features

- **Readiness Probes** - Ensure pods are ready before receiving traffic
- **Liveness Probes** - Automatically restart unhealthy pods
- **Resource Limits** - Prevent resource exhaustion
- **Pod Disruption Budgets** - Maintain availability during node maintenance

## 📊 Monitoring Capabilities

### Metrics Collection

- **Kubernetes metrics** - Nodes, pods, containers
- **Application metrics** - Custom metrics via Prometheus annotations
- **System metrics** - CPU, memory, disk, network
- **Service discovery** - Automatic target discovery

### Log Aggregation

- **Container logs** - All Kubernetes pod logs
- **Application logs** - Structured logging support
- **Log parsing** - Automatic label extraction

### Distributed Tracing

- **OpenTelemetry traces** - End-to-end request tracing
- **Service dependencies** - Automatic service graph

## 🛠️ Common Operations

### View Logs

```bash
# Prometheus logs
make logs-prometheus

# Grafana logs
make logs-grafana

# Loki logs
make logs-loki

# Mimir logs
make logs-mimir

# Alloy logs
make logs-alloy

# OpenTelemetry Collector logs
make logs-otel
```

### Test Endpoints

```bash
make test-endpoints
```

### Rollback Deployment

```bash
make ansible-rollback
```

### Destroy All Resources

```bash
make destroy
```

### Clean Up

```bash
make clean
```

## 🔒 Security Considerations

⚠️ **Before Production Deployment:**

1. **Change Default Passwords**
   - Update Grafana admin password in `kubernetes/grafana/deployment.yaml`
   - Use strong, randomly generated passwords
   - Store passwords in secure secret management systems

2. **Use Persistent Storage**
   - Replace `emptyDir` with `PersistentVolumeClaim` to prevent data loss
   - See DEPLOYMENT.md for configuration examples

3. **Enable TLS/SSL**
   - Configure cert-manager for automatic certificate management
   - Update ingress annotations for HTTPS redirect

4. **Security Features Included:**
   - Non-root containers (except Alloy which needs host access)
   - Security contexts with specific capabilities instead of privileged mode
   - Resource limits to prevent resource exhaustion
   - RBAC with least privilege principle
   - Service accounts with minimal permissions

5. **Additional Recommendations:**
   - Implement Network Policies for pod-to-pod communication
   - Use Pod Security Standards/Policies
   - Regular security updates and patches
   - Enable audit logging
   - Use external secret management (Vault, External Secrets Operator)

## 📈 Scaling

### Horizontal Scaling

Scale deployments:

```bash
kubectl scale deployment prometheus -n observability --replicas=3
kubectl scale deployment otel-collector -n observability --replicas=3
```

### Vertical Scaling

Update resource requests/limits in deployment files.

## 🐛 Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n observability
kubectl logs <pod-name> -n observability
```

### Service Discovery Issues

Check Prometheus targets:
```bash
kubectl port-forward -n observability svc/prometheus-service 9090:9090
# Visit http://localhost:9090/targets
```

### Ingress Not Working

```bash
kubectl get ingress -n observability
kubectl describe ingress observability-ingress -n observability
```

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Mimir Documentation](https://grafana.com/docs/mimir/)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [Ansible Documentation](https://docs.ansible.com/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Authors

- **Dapravith** - Initial work

## 🙏 Acknowledgments

- Prometheus community
- Grafana Labs
- OpenTelemetry community
- Kubernetes community