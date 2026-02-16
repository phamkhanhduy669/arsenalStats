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
          image             = "arsenal-flink:local-v2"
          name              = "jobmanager"
          image_pull_policy = "IfNotPresent"
          args              = ["jobmanager"]
          env {
            name  = "JOB_MANAGER_RPC_ADDRESS"
            value = "jobmanager"
          }
          port { container_port = 8081 }
          port { container_port = 6123 }
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
          image_pull_policy = "IfNotPresent"
          args              = ["taskmanager"]
          env {
            name  = "JOB_MANAGER_RPC_ADDRESS"
            value = "jobmanager"
          }
          env {
            name  = "TASK_MANAGER_NUMBER_OF_TASK_SLOTS"
            value = "2"
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
          image             = "arsenal-flink:local-v2"
          name              = "job-submitter"
          image_pull_policy = "IfNotPresent"
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
