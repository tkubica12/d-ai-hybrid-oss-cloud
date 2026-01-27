locals {
  law_name        = "log-${var.base_name}"
  monitor_ws_name = "prom-${var.base_name}"
  grafana_name    = "graf-${var.base_name}"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.law_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_monitor_workspace" "prom" {
  name                = local.monitor_ws_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_dashboard_grafana" "main" {
  name                              = local.grafana_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  sku                               = "Standard"
  grafana_major_version             = 11
  public_network_access_enabled     = true
  zone_redundancy_enabled           = false
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  tags                              = var.tags
}

output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.main.id }
output "log_analytics_workspace_name" { value = azurerm_log_analytics_workspace.main.name }
output "log_analytics_customer_id" { value = azurerm_log_analytics_workspace.main.workspace_id }
output "monitor_workspace_id" { value = azurerm_monitor_workspace.prom.id }
output "grafana_id" { value = azurerm_dashboard_grafana.main.id }