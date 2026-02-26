resource "kubernetes_stateful_set_v1" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
    labels    = { app = "zookeeper" }
  }

  spec {
    service_name = "zookeeper"
    replicas     = 1

    selector {
      match_labels = { app = "zookeeper" }
    }

    template {
      metadata {
        labels = { app = "zookeeper" }
      }

      spec {
        container {
          name  = "zookeeper"
          image = "confluentinc/cp-zookeeper:7.7.7"

          env {
            name  = "ZOOKEEPER_CLIENT_PORT"
            value = "2181"
          }
          env {
            name  = "ZOOKEEPER_TICK_TIME"
            value = "2000"
          }
          env {
            name  = "ZOOKEEPER_DATA_DIR"
            value = "/var/lib/zookeeper/data"
          }

          port {
            container_port = 2181
          }

          volume_mount {
            name       = "zookeeper-data"
            mount_path = "/var/lib/zookeeper/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "zookeeper-data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
        resources {
          requests = { storage = "2Gi" }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    cluster_ip = "None"
    selector   = { app = "zookeeper" }

    port {
      port        = 2181
      target_port = 2181
    }
  }
}
