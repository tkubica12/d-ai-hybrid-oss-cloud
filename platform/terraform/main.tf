resource "azurerm_resource_group" "main" {
  name     = "rg-${local.base_name}"
  location = var.location
}

resource "random_string" "main" {
  length  = 4
  special = false
  upper   = false
  numeric = false
  lower   = true
}

data "azurerm_client_config" "current" {}

module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  base_name           = local.base_name
  base_name_nodash    = local.base_name_nodash
  vnet_cidr           = "10.10.0.0/16"
  tags = {
    environment = "demo"
  }
}

module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  base_name           = local.base_name
  tags = {
    environment = "demo"
  }
}

module "aks_kaito" {
  source                     = "./modules/aks-kaito"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  base_name                  = local.base_name
  subnet_id_node             = module.networking.subnet_ids["aks"]
  subnet_id_api              = module.networking.subnet_ids["aks-api"]
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  monitor_workspace_id       = module.monitoring.monitor_workspace_id
  virtual_network_id         = module.networking.vnet_id
  resource_group_id          = azurerm_resource_group.main.id
  tags = {
    environment = "demo"
  }
  depends_on = [module.monitoring, module.networking]
}

module "ai_platform" {
  source              = "./modules/ai-platform"
  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  base_name           = local.base_name
  tags = {
    environment = "demo"
  }
  # Use enabled foundry models from catalog
  foundry_models = local.enabled_foundry_models
}

module "kaito" {
  source = "./modules/kaito"

  enabled_models = local.enabled_kaito_models

  # Pass kubernetes credentials from aks_kaito module
  # This creates an implicit dependency - module waits for aks_kaito to complete
  kube_host                   = module.aks_kaito.aks_kube_config_host
  kube_cluster_ca_certificate = module.aks_kaito.aks_cluster_ca_certificate
  kube_client_certificate     = module.aks_kaito.aks_client_certificate
  kube_client_key             = module.aks_kaito.aks_client_key
}
