variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "Kubernetes namespace for observability stack"
  type        = string
  default     = "observability"
}

variable "prometheus_replicas" {
  description = "Number of Prometheus replicas for high availability"
  type        = number
  default     = 2
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "domain" {
  description = "Domain for ingress"
  type        = string
  default     = "example.com"
}

variable "enable_mimir" {
  description = "Enable Mimir for long-term storage"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = true
}

variable "enable_opentelemetry" {
  description = "Enable OpenTelemetry collector"
  type        = bool
  default     = true
}
