resource "kubernetes_persistent_volume_claim_v1" "flink_checkpoints" {
  wait_until_bound = false

  metadata {
    name      = "flink-checkpoints-pvc"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = { storage = "5Gi" }
    }
  }
}

# --- JOBMANAGER ---
resource "kubernetes_deployment_v1" "jobmanager" {
  metadata {
    name      = "jobmanager"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "jobmanager" } }

    template {
      metadata { labels = { app = "jobmanager" } }

      spec {
        container {
          image             = "arsenal-flink:local"
          name              = "jobmanager"
          image_pull_policy = "Always"
          args              = ["jobmanager"]

          env {
            name  = "JOB_MANAGER_RPC_ADDRESS"
            value = "jobmanager"
          }
          env {
            name  = "FLINK_PROPERTIES"
            value = <<-EOT
              jobmanager.rpc.address: jobmanager
              state.backend: filesystem
              state.checkpoints.dir: file:///flink/checkpoints
              state.savepoints.dir: file:///flink/savepoints
              execution.checkpointing.interval: 10000
              execution.checkpointing.min-pause: 5000
              execution.checkpointing.timeout: 20000
            EOT
          }

          port { container_port = 8081 }
          port { container_port = 6123 }

          volume_mount {
            name       = "flink-checkpoints"
            mount_path = "/flink/checkpoints"
          }
          volume_mount {
            name       = "flink-checkpoints"
            mount_path = "/flink/savepoints"
            sub_path   = "savepoints"
          }
        }

        volume {
          name = "flink-checkpoints"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.flink_checkpoints.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "jobmanager" {
  metadata {
    name      = "jobmanager"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    selector = { app = "jobmanager" }
    port {
      name        = "ui"
      port        = 8081
      target_port = 8081
    }
    port {
      name        = "rpc"
      port        = 6123
      target_port = 6123
    }
    type = "NodePort"
  }
}

# --- TASKMANAGER ---
resource "kubernetes_deployment_v1" "taskmanager" {
  metadata {
    name      = "taskmanager"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    replicas = 3
    selector { match_labels = { app = "taskmanager" } }

    template {
      metadata { labels = { app = "taskmanager" } }

      spec {
        container {
          image             = "arsenal-flink:local"
          name              = "taskmanager"
          image_pull_policy = "Always"
          args              = ["taskmanager"]

          env {
            name  = "JOB_MANAGER_RPC_ADDRESS"
            value = "jobmanager"
          }
          env {
            name  = "TASK_MANAGER_NUMBER_OF_TASK_SLOTS"
            value = "2"
          }
          env {
            name  = "FLINK_PROPERTIES"
            value = <<-EOT
              jobmanager.rpc.address: jobmanager
              state.backend: filesystem
              state.checkpoints.dir: file:///flink/checkpoints
              taskmanager.numberOfTaskSlots: 2
            EOT
          }

          volume_mount {
            name       = "flink-checkpoints"
            mount_path = "/flink/checkpoints"
          }
        }

        volume {
          name = "flink-checkpoints"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.flink_checkpoints.metadata[0].name
          }
        }
      }
    }
  }
}

# --- FLINK JOB SUBMITTER ---
resource "kubernetes_job_v1" "flink_job_submitter" {
  metadata {
    name      = "flink-job-submitter"
    namespace = kubernetes_namespace_v1.arsenal_stats.metadata[0].name
  }

  spec {
    template {
      metadata {}
      spec {
        restart_policy = "Never"

        init_container {
          name    = "wait-for-flink"
          image   = "busybox:1.35"
          command = ["sh", "-c", "until nc -z jobmanager 8081; do echo 'Waiting for Flink JobManager...'; sleep 5; done; sleep 15"]
        }

        container {
          image             = "arsenal-flink:local"
          name              = "job-submitter"
          image_pull_policy = "Always"
          command           = ["flink", "run", "-m", "jobmanager:8081", "-py", "/opt/flink/usrlib/code/match_stream.py"]
        }
      }
    }
    backoff_limit = 2
  }

  wait_for_completion = false

  depends_on = [
    kubernetes_deployment_v1.jobmanager,
    kubernetes_deployment_v1.taskmanager
  ]
}
