#!/bin/bash

# Quick Start Script for Observability Stack
# This script deploys the complete observability stack on a Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    print_success "kubectl found"
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
    
    # Check cluster nodes
    NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    print_success "Found $NODES node(s) in cluster"
}

deploy_namespace() {
    print_info "Creating observability namespace..."
    kubectl apply -f kubernetes/namespaces/observability.yaml
    print_success "Namespace created"
}

deploy_prometheus() {
    print_info "Deploying Prometheus..."
    kubectl apply -f kubernetes/prometheus/configmap.yaml
    kubectl apply -f kubernetes/prometheus/deployment.yaml
    print_success "Prometheus deployed"
}

deploy_grafana() {
    print_info "Deploying Grafana..."
    kubectl apply -f kubernetes/grafana/deployment.yaml
    print_success "Grafana deployed"
}

deploy_loki() {
    print_info "Deploying Loki..."
    kubectl apply -f kubernetes/loki/deployment.yaml
    print_success "Loki deployed"
}

deploy_mimir() {
    print_info "Deploying Mimir..."
    kubectl apply -f kubernetes/mimir/deployment.yaml
    print_success "Mimir deployed"
}

deploy_alloy() {
    print_info "Deploying Grafana Alloy..."
    kubectl apply -f kubernetes/alloy/deployment.yaml
    print_success "Grafana Alloy deployed"
}

deploy_opentelemetry() {
    print_info "Deploying OpenTelemetry Collector..."
    kubectl apply -f kubernetes/opentelemetry/deployment.yaml
    print_success "OpenTelemetry Collector deployed"
}

deploy_ingress() {
    print_info "Deploying Ingress..."
    kubectl apply -f kubernetes/ingress/ingress.yaml
    print_success "Ingress deployed"
}

wait_for_pods() {
    print_info "Waiting for pods to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n observability --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=grafana -n observability --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=loki -n observability --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=mimir -n observability --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=otel-collector -n observability --timeout=300s || true
    print_success "Pods are ready"
}

display_status() {
    print_info "Deployment Status:"
    echo ""
    kubectl get all -n observability
    echo ""
}

display_access_info() {
    print_success "Deployment complete!"
    echo ""
    print_info "Access Services:"
    echo ""
    echo "Grafana:"
    echo "  kubectl port-forward -n observability svc/grafana-service 3000:3000"
    echo "  Then visit: http://localhost:3000"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    echo "Prometheus:"
    echo "  kubectl port-forward -n observability svc/prometheus-service 9090:9090"
    echo "  Then visit: http://localhost:9090"
    echo ""
    echo "To see all pods:"
    echo "  kubectl get pods -n observability"
    echo ""
    echo "To view logs:"
    echo "  make logs-grafana"
    echo "  make logs-prometheus"
    echo ""
}

main() {
    echo "=================================="
    echo "Observability Stack Quick Start"
    echo "=================================="
    echo ""
    
    check_prerequisites
    echo ""
    
    deploy_namespace
    deploy_prometheus
    deploy_grafana
    deploy_loki
    deploy_mimir
    deploy_alloy
    deploy_opentelemetry
    deploy_ingress
    
    echo ""
    wait_for_pods
    echo ""
    display_status
    echo ""
    display_access_info
}

# Run main function
main
