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
