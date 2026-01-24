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
  foundry_models = [
    {
      name       = "gpt-5.2"
      model_name = "gpt-5.2"
      version    = "2025-12-11"
      sku_name   = "GlobalStandard"
      capacity   = 100
    },
    {
      name       = "gpt-5-mini"
      model_name = "gpt-5-mini"
      version    = "2025-08-07"
      sku_name   = "GlobalStandard"
      capacity   = 100
    },
    {
      name       = "gpt-4.1"
      model_name = "gpt-4.1"
      version    = "2025-04-14"
      sku_name   = "GlobalStandard"
      capacity   = 100
    },
    {
      name       = "gpt-4.1-mini"
      model_name = "gpt-4.1-mini"
      version    = "2025-04-14"
      sku_name   = "GlobalStandard"
      capacity   = 100
    },
    {
      name       = "gpt-4.1-nano"
      model_name = "gpt-4.1-nano"
      version    = "2025-04-14"
      sku_name   = "GlobalStandard"
      capacity   = 100
    }
  ]
}
