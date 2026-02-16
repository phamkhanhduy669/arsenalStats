resource "kubernetes_deployment_v1" "batching" {
  metadata {
    name      = "batching-etl"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "batching" } }
    template {
      metadata { labels = { app = "batching" } }
      spec {
        container {
          image             = "arsenal-batching:local"
          name              = "batching"
          image_pull_policy = "IfNotPresent"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.arsenal_env.metadata[0].name
            }
          }

          env {
            name  = "TZ"
            value = "Asia/Ho_Chi_Minh"
          }

          env {
            name  = "DB_HOST"
            value = "postgres"
          }

          env {
            name  = "DB_PORT"
            value = "5432"
          }

          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.arsenal_env.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.arsenal_env.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.arsenal_env.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
        }
      }
    }
  }
}
