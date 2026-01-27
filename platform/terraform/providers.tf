terraform {
  required_version = ">= 1.5"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "= 2.7.0" # Pinned to 2.7.0 - v2.8.0 has bug causing "Missing Resource Identity After Read" errors
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "azuread" {}

provider "random" {}

provider "tls" {}

provider "local" {}

# Data source to get AKS kubeconfig credentials
# NOTE: This data source requires AKS to already exist.
# On first deployment, run: terraform apply -target=module.aks_kaito
# Then run: terraform apply (to deploy Helm charts)
data "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${local.base_name}"
  resource_group_name = "rg-${local.base_name}"
}

# Helm provider configured with AKS credentials from data source
# Uses client certificates for authentication (works with local accounts enabled)
provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}
