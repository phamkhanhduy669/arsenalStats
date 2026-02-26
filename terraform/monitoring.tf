resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_config_map_v1" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }
  data = {
    "prometheus.yml" = file("${path.module}/../prometheus/prometheus.yml")
    "rules.yml"      = file("${path.module}/../prometheus/rules.yml")
  }
}


resource "kubernetes_config_map_v1" "grafana_dashboards" {
  metadata {
    name      = "arsenal-grafana-dashboards"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    for dashboard_file in fileset("${path.module}/../grafana/dashboards", "*.json") :
    dashboard_file => file("${path.module}/../grafana/dashboards/${dashboard_file}")
  }
}

resource "kubernetes_config_map_v1" "grafana_datasource_provisioning" {
  metadata {
    name      = "grafana-datasource-provisioning"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    "prometheus.yml" = file("${path.module}/../grafana/provisioning/datasources/prometheus.yml")
  }
}

resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  version    = "56.0.0"
  timeout    = 900
  wait       = false
  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
        }
      }
      grafana = {
        adminPassword = "admin"
        service = {
          type = "LoadBalancer"
        }
        sidecar = {
          dashboards = {
            enabled         = true
            label           = "grafana_dashboard"
            searchNamespace = "ALL"
          }
        }
        extraConfigmapMounts = [
          {
            name      = "datasource-provisioning"
            configMap = kubernetes_config_map_v1.grafana_datasource_provisioning.metadata[0].name
            mountPath = "/etc/grafana/provisioning/datasources"
            readOnly  = true
          }
        ]
      }
    })
  ]

  depends_on = [
    kubernetes_config_map_v1.grafana_dashboards,
    kubernetes_config_map_v1.grafana_datasource_provisioning
  ]
}

