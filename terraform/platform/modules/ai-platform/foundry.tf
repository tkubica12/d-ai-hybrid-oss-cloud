# Azure AI Foundry Resource (AIServices account)
# This is the parent resource that hosts model deployments
resource "azapi_resource" "foundry" {
  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name      = local.foundry_name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  # Disable schema validation - allowProjectManagement is a newer property
  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      customSubDomainName    = local.foundry_name
      publicNetworkAccess    = "Enabled"
      disableLocalAuth       = true # Key auth disabled - use managed identity
      allowProjectManagement = true # Required to enable Foundry projects
    }
  }

  response_export_values = ["properties.endpoint", "identity.principalId"]

  lifecycle {
    ignore_changes = [
      # Ignore identity changes to avoid azapi provider bug with identity updates
      identity
    ]
  }
}

# Foundry Project - child resource required for the new Microsoft Foundry portal
resource "azapi_resource" "foundry_project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = "default"
  parent_id = azapi_resource.foundry.id

  # Disable schema validation for newer API
  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind     = "AIServices"
    location = var.location
    properties = {
      isDefault = true
    }
  }

  response_export_values = ["properties.endpoints", "identity.principalId"]

  lifecycle {
    ignore_changes = [
      # Ignore identity changes to avoid azapi provider bug with identity updates
      identity
    ]
  }
}

# Model deployments in Foundry - deployed sequentially to avoid conflicts - deployed sequentially to avoid conflicts
# Azure Cognitive Services only allows one deployment operation at a time
resource "azapi_resource" "foundry_deployment" {
  for_each = { for idx, m in var.foundry_models : m.name => merge(m, { index = idx }) }

  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-06-01"
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

  # Create deployments sequentially by depending on the previous one
  depends_on = [azapi_resource.foundry_project]

  lifecycle {
    # Retry on conflict errors
    create_before_destroy = false
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# Grant APIM managed identity access to Foundry
resource "azurerm_role_assignment" "apim_cognitive_services" {
  scope                = azapi_resource.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.apim.output.identity.principalId

  depends_on = [azapi_resource.apim, azapi_resource.foundry]
}
