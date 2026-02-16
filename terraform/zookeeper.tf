resource "kubernetes_deployment_v1" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
    labels    = { app = "zookeeper" }
  }

  spec {
    replicas = 1

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

          port {
            container_port = 2181
          }
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
    selector = { app = "zookeeper" }

    port {
      port        = 2181
      target_port = 2181
    }
  }
}
