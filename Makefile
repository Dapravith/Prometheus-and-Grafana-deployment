.PHONY: help init deploy destroy status logs clean validate terraform-init terraform-plan terraform-apply ansible-deploy

help: ## Display this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the project
	@echo "Initializing Terraform..."
	cd terraform && terraform init
	@echo "Installing Ansible dependencies..."
	ansible-galaxy collection install kubernetes.core

validate: ## Validate Terraform and Kubernetes configurations
	@echo "Validating Terraform configuration..."
	cd terraform && terraform validate
	@echo "Validating Kubernetes manifests..."
	kubectl apply --dry-run=client -f kubernetes/namespaces/ || true
	kubectl apply --dry-run=client -f kubernetes/prometheus/ || true
	kubectl apply --dry-run=client -f kubernetes/grafana/ || true
	kubectl apply --dry-run=client -f kubernetes/loki/ || true
	kubectl apply --dry-run=client -f kubernetes/mimir/ || true
	kubectl apply --dry-run=client -f kubernetes/alloy/ || true
	kubectl apply --dry-run=client -f kubernetes/opentelemetry/ || true
	kubectl apply --dry-run=client -f kubernetes/ingress/ || true

terraform-init: ## Initialize Terraform
	cd terraform && terraform init

terraform-plan: ## Plan Terraform changes
	cd terraform && terraform plan

terraform-apply: ## Apply Terraform changes
	cd terraform && terraform apply -auto-approve

deploy: ## Deploy the observability stack using kubectl
	@echo "Creating namespace..."
	kubectl apply -f kubernetes/namespaces/
	@echo "Deploying Prometheus..."
	kubectl apply -f kubernetes/prometheus/
	@echo "Deploying Grafana..."
	kubectl apply -f kubernetes/grafana/
	@echo "Deploying Loki..."
	kubectl apply -f kubernetes/loki/
	@echo "Deploying Mimir..."
	kubectl apply -f kubernetes/mimir/
	@echo "Deploying Grafana Alloy..."
	kubectl apply -f kubernetes/alloy/
	@echo "Deploying OpenTelemetry Collector..."
	kubectl apply -f kubernetes/opentelemetry/
	@echo "Deploying Ingress..."
	kubectl apply -f kubernetes/ingress/
	@echo "Deployment complete!"

ansible-deploy: ## Deploy using Ansible
	ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy.yml

ansible-rollback: ## Rollback using Ansible
	ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/rollback.yml

status: ## Check deployment status
	@echo "Checking deployment status..."
	kubectl get all -n observability
	@echo ""
	@echo "Checking ingress..."
	kubectl get ingress -n observability

logs-prometheus: ## Get Prometheus logs
	kubectl logs -n observability -l app=prometheus --tail=100

logs-grafana: ## Get Grafana logs
	kubectl logs -n observability -l app=grafana --tail=100

logs-loki: ## Get Loki logs
	kubectl logs -n observability -l app=loki --tail=100

logs-mimir: ## Get Mimir logs
	kubectl logs -n observability -l app=mimir --tail=100

logs-alloy: ## Get Alloy logs
	kubectl logs -n observability -l app=alloy --tail=100

logs-otel: ## Get OpenTelemetry Collector logs
	kubectl logs -n observability -l app=otel-collector --tail=100

port-forward-grafana: ## Port forward Grafana to localhost:3000
	kubectl port-forward -n observability svc/grafana-service 3000:3000

port-forward-prometheus: ## Port forward Prometheus to localhost:9090
	kubectl port-forward -n observability svc/prometheus-service 9090:9090

destroy: ## Destroy all resources
	@echo "Deleting all resources..."
	kubectl delete namespace observability --ignore-not-found=true
	@echo "Resources deleted!"

clean: ## Clean up temporary files
	rm -rf terraform/.terraform
	rm -rf terraform/terraform.tfstate*
	rm -rf ansible/*.retry

test-endpoints: ## Test all service endpoints
	@echo "Testing Prometheus..."
	@kubectl run -n observability curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- curl -s http://prometheus-service:9090/-/healthy || true
	@echo "Testing Grafana..."
	@kubectl run -n observability curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- curl -s http://grafana-service:3000/api/health || true
	@echo "Testing Loki..."
	@kubectl run -n observability curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- curl -s http://loki-service:3100/ready || true
