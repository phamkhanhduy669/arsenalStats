resource "kubernetes_secret_v1" "arsenal_env" {
  metadata {
    name      = "arsenal-env-secret"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }


  data = {
    RAPIDAPI_KEY      = var.rapidapi_key
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_USER     = var.postgres_user
    POSTGRES_DB       = var.postgres_db
  }
}
