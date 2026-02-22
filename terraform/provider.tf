terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.0"
    }
  }

}

provider "kubernetes" {
  config_path    = pathexpand(var.kube_config)
  config_context = "docker-desktop"
}

provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kube_config)
    config_context = "docker-desktop"
  }
}