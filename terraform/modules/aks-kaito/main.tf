locals {
  aks_name        = "aks-${var.base_name}"
  uai_name        = "uai-${var.base_name}"
  kaito_extension = "kaito"
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = local.uai_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azapi_resource" "aks" {
  type          = "Microsoft.ContainerService/managedClusters@2025-05-01"
  name          = local.aks_name
  parent_id     = var.resource_group_id
  location      = var.location
  tags          = var.tags
  ignore_casing = true
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }
  body = {
    sku = {
      name = "Base"
      tier = "Standard"
    }
    properties = {
      dnsPrefix  = substr(var.base_name, 0, 40)
      enableRBAC = true
      linuxProfile = {
        adminUsername = "azureuser"
        ssh = {
          publicKeys = [
            {
              keyData = tls_private_key.ssh.public_key_openssh
            }
          ]
        }
      }
      agentPoolProfiles = [
        {
          name         = "systempool"
          count        = 1
          vmSize       = "Standard_DS2_v2"
          osType       = "Linux"
          mode         = "System"
          vnetSubnetID = var.subnet_id_node
        }
      ]
      networkProfile = {
        networkPlugin     = "azure"
        networkPluginMode = "overlay"
        networkPolicy     = "cilium"
        networkDataplane  = "cilium"
        loadBalancerSku   = "Standard"
        dnsServiceIP      = "10.200.0.10"
        serviceCidr       = "10.200.0.0/16"
      }
      apiServerAccessProfile = {
        enableVnetIntegration = true
        subnetId              = var.subnet_id_api
      }
      nodeProvisioningProfile = {
        mode = "Auto"
      }
      aiToolchainOperatorProfile = {
        enabled = true
      }
      azureMonitorProfile = {
        metrics = {
          enabled = true
          kubeStateMetrics = {
            metricAnnotationsAllowList = "*"
            metricLabelsAllowlist      = "*"
          }
        }
      }
      addonProfiles = {
        omsagent = {
          enabled = true
          config = {
            logAnalyticsWorkspaceResourceID = var.log_analytics_workspace_id
          }
        }
      }
    }
  }
  depends_on = [azurerm_user_assigned_identity.aks]
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "monitor_reader" {
  scope                            = var.monitor_workspace_id
  role_definition_name             = "Monitoring Data Reader"
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "log_contributor" {
  scope                            = var.log_analytics_workspace_id
  role_definition_name             = "Log Analytics Contributor"
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                            = var.virtual_network_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                            = azapi_resource.aks.id
  role_definition_name             = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id                     = data.azurerm_client_config.current.object_id
}

output "aks_id" { value = azapi_resource.aks.id }
output "aks_name" { value = local.aks_name }
output "aks_kubelet_identity_object_id" { value = null }
output "aks_principal_id" { value = azurerm_user_assigned_identity.aks.principal_id }

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "ssh_private_key_pem" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}
