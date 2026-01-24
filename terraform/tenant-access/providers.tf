terraform {
  required_version = ">= 1.5"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
  }
}

# Azure providers
provider "azurerm" {
  subscription_id = local.platform.subscription_id
  features {}
}

provider "azapi" {
  subscription_id = local.platform.subscription_id
}

# Kubernetes and Helm providers - configured using AKS credentials
# Uses client certificate authentication (local accounts enabled on AKS)
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
  }
}
