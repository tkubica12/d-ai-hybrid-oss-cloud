resource "azurerm_user_assigned_identity" "aks" {
  name                = local.uai_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "aso" {
  name                = local.aso_identity_name
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
  response_export_values = [
    "properties.oidcIssuerProfile.issuerURL"
  ]
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
          vmSize       = "Standard_D4ads_v6"
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
      securityProfile = {
        workloadIdentity = {
          enabled = true
        }
      }
      oidcIssuerProfile = {
        enabled = true
      }
    }
  }
  depends_on = [
    azurerm_user_assigned_identity.aks,
    azurerm_user_assigned_identity.aso
  ]
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_federated_identity_credential" "aso" {
  name                = "aso-workload-identity"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.aso.id
  issuer              = try(azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL, "")
  subject             = local.aso_service_account_subject
  audience            = ["api://AzureADTokenExchange"]

  depends_on = [azapi_resource.aks]
}
