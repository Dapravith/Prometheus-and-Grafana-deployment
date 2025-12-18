resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace

    labels = {
      name        = var.namespace
      environment = "production"
      managed-by  = "terraform"
    }
  }
}
