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

resource "kubernetes_deployment_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
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
        }

        volume {
          name = "init-scripts"
          config_map {
            name = kubernetes_config_map_v1.postgres_init_scripts.metadata[0].name
          }
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
    selector = {
      app = kubernetes_deployment_v1.postgres.spec[0].template[0].metadata[0].labels.app
    }
    port {
      port        = 5432
      target_port = 5432
    }
  }
}
