resource "kubernetes_deployment_v1" "kafka" {

  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
    labels    = { app = "kafka" }
  }

  spec {

    replicas = 1

    selector {
      match_labels = { app = "kafka" }
    }

    template {

      metadata {
        labels = { app = "kafka" }
      }

      spec {

        enable_service_links = false

        container {

          name  = "kafka"
          image = "confluentinc/cp-kafka:7.7.7"

          env {
            name  = "KAFKA_BROKER_ID"
            value = "1"
          }

          env {
            name  = "KAFKA_ZOOKEEPER_CONNECT"
            value = "zookeeper:2181"
          }

          env {
            name  = "KAFKA_LISTENERS"
            value = "PLAINTEXT://0.0.0.0:9092"
          }

          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://kafka:9092"
          }

          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "PLAINTEXT:PLAINTEXT"
          }

          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "PLAINTEXT"
          }

          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }

          env {
            name  = "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS"
            value = "0"
          }

          port {
            container_port = 9092
          }

          startup_probe {
            tcp_socket { port = 9092 }
            initial_delay_seconds = 60
            period_seconds        = 15
            failure_threshold     = 40
          }

          readiness_probe {
            tcp_socket { port = 9092 }
            initial_delay_seconds = 60
            period_seconds        = 10
          }

          liveness_probe {
            tcp_socket { port = 9092 }
            initial_delay_seconds = 90
            period_seconds        = 20
          }

        }
      }
    }
  }
}

resource "kubernetes_service_v1" "kafka" {

  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {

    selector = { app = "kafka" }

    port {
      port        = 9092
      target_port = 9092
    }
  }
}
