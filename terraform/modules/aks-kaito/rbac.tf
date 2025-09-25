resource "azurerm_role_assignment" "monitor_reader" {
  scope                = var.monitor_workspace_id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "log_contributor" {
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = var.virtual_network_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = azapi_resource.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
