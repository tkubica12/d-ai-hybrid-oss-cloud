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
  kaito_model_ips     = local.kaito_model_ips
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
  apim_subnet_id      = module.networking.subnet_ids["api-management"]
  tags = {
    environment = "demo"
  }
  # Use enabled foundry models from catalog
  foundry_models = local.enabled_foundry_models

  # Pass enabled KAITO models with their service IPs for unified API routing
  kaito_models = {
    for name, model in local.enabled_kaito_models :
    name => {
      display_name = model.displayName
      service_ip   = model.staticIP
      preset       = model.preset
    }
  }
}

module "kaito" {
  source = "./modules/kaito"

  enabled_models  = local.enabled_kaito_models
  dns_zone_name   = local.kaito_dns_zone_name
  model_ips       = local.kaito_model_ips
  aks_subnet_name = local.aks_subnet_name

  # Helm provider is passed from root to ensure proper dependency ordering
  providers = {
    helm = helm
  }

  # Explicit dependency ensures AKS is ready before Helm operations
  depends_on = [module.aks_kaito, module.networking]
}
