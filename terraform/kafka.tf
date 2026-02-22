resource "kubernetes_stateful_set_v1" "kafka" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
    labels    = { app = "kafka" }
  }

  spec {
    service_name = "kafka"
    replicas     = 1

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
          env {
            name  = "KAFKA_LOG_DIRS"
            value = "/var/lib/kafka/data"
          }
          env {
            name  = "KAFKA_LOG_RETENTION_HOURS"
            value = "168"
          }

          port {
            container_port = 9092
          }

          volume_mount {
            name       = "kafka-data"
            mount_path = "/var/lib/kafka/data"
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

    volume_claim_template {
      metadata {
        name = "kafka-data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
        resources {
          requests = { storage = "10Gi" }
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
    cluster_ip = "None"
    selector   = { app = "kafka" }

    port {
      port        = 9092
      target_port = 9092
    }
  }
}

resource "kubernetes_job_v1" "kafka_topic_creator" {
  metadata {
    name      = "kafka-topic-creator"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    backoff_limit = 5
    template {
      metadata {
        labels = { app = "kafka-topic-creator" }
      }

      spec {
        restart_policy = "Never"
        container {
          name  = "topic-creator"
          image = "confluentinc/cp-kafka:7.7.7"

          command = ["/bin/bash", "-c"]
          args = [
            "/usr/bin/kafka-topics --create --if-not-exists --bootstrap-server kafka:9092 --topic arsenal_live_match --partitions 3 --replication-factor 1 && echo 'Topic arsenal_live_match created'"
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_stateful_set_v1.kafka,
    kubernetes_service_v1.kafka
  ]
}
