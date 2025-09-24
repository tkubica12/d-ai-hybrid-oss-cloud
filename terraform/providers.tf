terraform {
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
      source = "hashicorp/random"
      version = ">= 3"
    }
    tls = {
      source = "hashicorp/tls"
      version = ">= 4"
    }
  }
}

provider "azurerm" {
  subscription_id = "673af34d-6b28-41dc-bc7b-f507418045e6"
  features {}
}

provider "azapi" {
  subscription_id = "673af34d-6b28-41dc-bc7b-f507418045e6"
}

provider "azuread" {}

provider "random" {}

provider "tls" {}

