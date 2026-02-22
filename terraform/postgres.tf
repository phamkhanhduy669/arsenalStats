resource "kubernetes_config_map_v1" "postgres_init_scripts" {
  metadata {
    name      = "postgres-init-scripts"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  data = {
    "01-create_table.sql" = file("${path.module}/../postgesql/create_table.sql")
    "02-trigger.sql"      = file("${path.module}/../postgesql/trigger.sql")
  }
}

resource "kubernetes_stateful_set_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = { app = "postgres" }
    }

    template {
      metadata {
        labels = { app = "postgres" }
      }

      spec {
        container {
          image = "postgres:15"
          name  = "postgres"

          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_DB"
            value = "project_1"
          }

          port {
            container_port = 5432
          }

          volume_mount {
            name       = "init-scripts"
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }
          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 20
          }
        }

        volume {
          name = "init-scripts"
          config_map {
            name = kubernetes_config_map_v1.postgres_init_scripts.metadata[0].name
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgres-data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
        resources {
          requests = { storage = "5Gi" }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    cluster_ip = "None"
    selector   = { app = "postgres" }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}
