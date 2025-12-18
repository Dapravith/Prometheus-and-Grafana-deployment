# Deployment Guide

This guide walks you through deploying the observability stack in different environments.

## Table of Contents

1. [Prerequisites Check](#prerequisites-check)
2. [Local Development (Minikube/Kind)](#local-development)
3. [Cloud Deployment (EKS/GKE/AKS)](#cloud-deployment)
4. [Production Deployment](#production-deployment)
5. [Post-Deployment Verification](#post-deployment-verification)
6. [Troubleshooting](#troubleshooting)

## Prerequisites Check

Before deploying, verify you have all required tools:

```bash
# Check kubectl
kubectl version --client

# Check Terraform
terraform --version

# Check Ansible
ansible --version

# Check Helm (optional)
helm version

# Check make
make --version
```

### Install Missing Tools

**kubectl**:
```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# macOS
brew install kubectl
```

**Terraform**:
```bash
# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# macOS
brew install terraform
```

**Ansible**:
```bash
# Linux
sudo apt update
sudo apt install ansible

# macOS
brew install ansible
```

## Local Development

### Option 1: Minikube

#### 1. Start Minikube

```bash
# Start with sufficient resources
minikube start --cpus=4 --memory=8192 --driver=docker

# Enable ingress addon
minikube addons enable ingress

# Verify cluster is running
kubectl cluster-info
```

#### 2. Deploy the Stack

```bash
# Initialize
make init

# Validate configurations
make validate

# Deploy
make deploy
```

#### 3. Access Services

```bash
# Get minikube IP
minikube ip

# Port forward to access Grafana
make port-forward-grafana

# Open browser to http://localhost:3000
# Username: admin, Password: admin
```

### Option 2: Kind (Kubernetes in Docker)

#### 1. Create Cluster

```bash
# Create kind-config.yaml
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# Create cluster
kind create cluster --config kind-config.yaml --name observability

# Install ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

#### 2. Deploy the Stack

```bash
make init
make deploy
```

## Cloud Deployment

### Amazon EKS

#### 1. Create EKS Cluster

```bash
# Using eksctl
eksctl create cluster \
  --name observability-cluster \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.large \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 6 \
  --managed

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name observability-cluster
```

#### 2. Install Ingress Controller

```bash
# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=observability-cluster
```

#### 3. Deploy Stack

```bash
make init
make deploy
```

### Google GKE

#### 1. Create GKE Cluster

```bash
# Create cluster
gcloud container clusters create observability-cluster \
  --region us-central1 \
  --num-nodes 3 \
  --machine-type n1-standard-4 \
  --enable-autoscaling \
  --min-nodes 3 \
  --max-nodes 6

# Get credentials
gcloud container clusters get-credentials observability-cluster --region us-central1
```

#### 2. Install Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

#### 3. Deploy Stack

```bash
make init
make deploy
```

### Azure AKS

#### 1. Create AKS Cluster

```bash
# Create resource group
az group create --name observability-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group observability-rg \
  --name observability-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group observability-rg --name observability-cluster
```

#### 2. Install Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

#### 3. Deploy Stack

```bash
make init
make deploy
```

## Production Deployment

### 1. Pre-Deployment Checklist

- [ ] Kubernetes cluster with sufficient resources (4+ CPU, 16GB+ RAM per node)
- [ ] Ingress controller installed
- [ ] DNS configured for ingress domains
- [ ] SSL/TLS certificates ready (or cert-manager installed)
- [ ] Persistent storage provisioner available
- [ ] Backup strategy defined
- [ ] Monitoring plan in place

### 2. Configuration Adjustments

#### Update Domain Names

Edit `kubernetes/ingress/ingress.yaml`:

```yaml
spec:
  rules:
  - host: grafana.yourdomain.com  # Change this
  - host: prometheus.yourdomain.com  # Change this
  # ... etc
```

#### Enable Persistent Storage

For production, replace `emptyDir` with `PersistentVolumeClaim` in deployments.

Example for Prometheus (`kubernetes/prometheus/deployment.yaml`):

```yaml
volumes:
- name: storage
  persistentVolumeClaim:
    claimName: prometheus-storage
```

Create PVC:

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
  storageClassName: standard  # Use your storage class
```

#### Adjust Resource Limits

Edit resource requests/limits in deployment files based on your workload:

```yaml
resources:
  requests:
    memory: "4Gi"    # Increase for production
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

#### Configure Authentication

Update Grafana admin password in `kubernetes/grafana/deployment.yaml`:

```yaml
env:
- name: GF_SECURITY_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: grafana-secrets
      key: admin-password
```

Create secret:

```bash
kubectl create secret generic grafana-secrets \
  --from-literal=admin-password='your-secure-password' \
  -n observability
```

### 3. Deploy with Ansible

```bash
# Review the playbook
cat ansible/playbooks/deploy.yml

# Run deployment
make ansible-deploy

# Monitor deployment
watch kubectl get pods -n observability
```

### 4. Configure DNS

Get the ingress external IP:

```bash
kubectl get ingress -n observability
```

Create DNS A records:
- `grafana.yourdomain.com` → Ingress IP
- `prometheus.yourdomain.com` → Ingress IP
- `loki.yourdomain.com` → Ingress IP
- `mimir.yourdomain.com` → Ingress IP

### 5. Enable TLS/SSL

#### Option A: Using cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

The ingress already has the cert-manager annotation configured.

## Post-Deployment Verification

### 1. Check Pod Status

```bash
# All pods should be Running
kubectl get pods -n observability

# Check for any issues
kubectl get events -n observability --sort-by='.lastTimestamp'
```

### 2. Verify Services

```bash
# Check services
kubectl get svc -n observability

# Test service endpoints
make test-endpoints
```

### 3. Access Grafana

```bash
# Port forward
make port-forward-grafana

# Or access via ingress
# https://grafana.yourdomain.com
```

#### Verify Datasources

1. Login to Grafana
2. Go to Configuration → Data Sources
3. Verify Prometheus, Loki, and Mimir are connected
4. Test each datasource

### 4. Check Prometheus Targets

```bash
# Port forward Prometheus
make port-forward-prometheus

# Visit http://localhost:9090/targets
# All targets should be "UP"
```

### 5. Verify Metrics Collection

In Grafana, run a query in Explore:

```promql
up{job="prometheus"}
```

You should see metrics being collected.

### 6. Verify Log Collection

In Grafana Explore with Loki datasource:

```logql
{namespace="observability"}
```

You should see logs from the observability stack.

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n observability

# Describe pod for events
kubectl describe pod <pod-name> -n observability

# Check logs
kubectl logs <pod-name> -n observability
```

Common issues:
- Insufficient resources: Scale down replicas or increase node resources
- Image pull errors: Check image names and registry access
- Configuration errors: Validate ConfigMaps

### Services Not Reachable

```bash
# Check service endpoints
kubectl get endpoints -n observability

# Test service internally
kubectl run -n observability curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- curl -v http://grafana-service:3000
```

### Ingress Not Working

```bash
# Check ingress
kubectl get ingress -n observability
kubectl describe ingress observability-ingress -n observability

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Prometheus Not Scraping Targets

1. Check Prometheus logs: `make logs-prometheus`
2. Verify RBAC permissions: `kubectl get clusterrolebinding prometheus`
3. Check target configuration in Prometheus UI
4. Verify pod annotations are correct

### Grafana Datasource Connection Failed

1. Check service DNS resolution inside Grafana pod:
   ```bash
   kubectl exec -n observability deploy/grafana -- nslookup prometheus-service.observability.svc.cluster.local
   ```
2. Verify services are running: `kubectl get svc -n observability`
3. Check datasource configuration in ConfigMap

### High Resource Usage

```bash
# Check resource usage
kubectl top pods -n observability
kubectl top nodes

# Adjust resource limits in deployment files
# Scale down replicas if needed
```

## Maintenance

### Updating Components

```bash
# Update image versions in deployment files
# Then apply changes
kubectl apply -f kubernetes/<component>/deployment.yaml

# Or redeploy
make deploy
```

### Backup

```bash
# Backup Grafana dashboards
kubectl exec -n observability deploy/grafana -- tar czf - /var/lib/grafana > grafana-backup.tar.gz

# Backup Prometheus data
kubectl exec -n observability deploy/prometheus -- tar czf - /prometheus > prometheus-backup.tar.gz
```

### Monitoring Stack Health

Create alerts for:
- Pod restarts
- High resource usage
- Failed scrapes
- Data ingestion issues

## Next Steps

1. **Configure Alerting**: Set up Alertmanager and alert rules
2. **Create Dashboards**: Build custom Grafana dashboards
3. **Instrument Applications**: Add Prometheus metrics to your apps
4. **Set Up Tracing**: Deploy Tempo for distributed tracing
5. **Implement Backup**: Automate backups of configurations and data
6. **Scale**: Adjust replicas and resources based on load
