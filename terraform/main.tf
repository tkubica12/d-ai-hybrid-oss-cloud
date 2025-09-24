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
  vnet_cidr           = "10.10.0.0/16" # can still override via variable if exposed later
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
