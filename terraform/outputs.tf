output "namespace" {
  description = "Observability namespace"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = "prometheus-service.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://grafana.${var.domain}"
}

output "loki_service" {
  description = "Loki service name"
  value = (
    var.enable_loki
    ? "loki-service.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local"
    : "disabled"
  )
}

output "mimir_service" {
  description = "Mimir service name"
  value = (
    var.enable_mimir
    ? "mimir-service.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local"
    : "disabled"
  )
}
