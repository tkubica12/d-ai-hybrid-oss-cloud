locals {
  aks_name        = "aks-${var.base_name}"
  uai_name        = "uai-${var.base_name}"
  kaito_extension = "kaito"
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}
