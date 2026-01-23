# Azure AI Foundry Resource (AIServices account)
# This is the parent resource that hosts model deployments
resource "azapi_resource" "foundry" {
  type      = "Microsoft.CognitiveServices/accounts@2024-10-01"
  name      = local.foundry_name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      customSubDomainName = local.foundry_name
      publicNetworkAccess = "Enabled"
      disableLocalAuth    = false
    }
  }

  response_export_values = ["properties.endpoint", "identity.principalId"]
}

# Model deployments in Foundry
resource "azapi_resource" "foundry_deployment" {
  for_each = { for m in var.foundry_models : m.name => m }

  type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
  name      = each.value.name
  parent_id = azapi_resource.foundry.id

  body = {
    sku = {
      name     = each.value.sku_name
      capacity = each.value.capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = each.value.model_name
        version = each.value.version
      }
    }
  }
}

# Grant APIM managed identity access to Foundry
resource "azurerm_role_assignment" "apim_cognitive_services" {
  scope                = azapi_resource.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.apim.output.identity.principalId

  depends_on = [azapi_resource.apim, azapi_resource.foundry]
}
