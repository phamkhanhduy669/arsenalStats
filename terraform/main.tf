resource "kubernetes_namespace_v1" "arsenal_stats" {
  metadata {
    name = "arsenal-stats"
  }
}
