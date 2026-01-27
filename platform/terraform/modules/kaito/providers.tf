# KAITO Module
# Manages KAITO workspace deployments and LoadBalancer services for OSS models
# Uses Helm provider which does NOT require cluster connection during plan

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

# Configure helm provider with credentials passed from parent
# Note: Helm 3.x uses assignment syntax for kubernetes config, not block syntax
provider "helm" {
  kubernetes = {
    host                   = var.kube_host
    cluster_ca_certificate = base64decode(var.kube_cluster_ca_certificate)
    client_certificate     = base64decode(var.kube_client_certificate)
    client_key             = base64decode(var.kube_client_key)
  }
}
