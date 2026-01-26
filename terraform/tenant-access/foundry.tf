# Per-team Foundry Resources
# Each team gets their own Foundry resource with a default project
# This allows visibility in the new Foundry portal while still sharing
# centralized model deployments via APIM gateway
# Note: Uses azapi as azurerm doesn't support all CognitiveServices features

resource "azapi_resource" "foundry_resource" {
  for_each = {
    for team_name, team in local.teams :
    team_name => team
    if team.foundry_enabled
  }

  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name      = "foundry-${each.value.name}"
  parent_id = local.platform.resource_group_id
  location  = local.platform.location

  # Disable schema validation for newer API properties
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
      customSubDomainName    = "foundry-${each.value.name}-${substr(md5(local.platform.resource_group_id), 0, 8)}"
      publicNetworkAccess    = "Enabled"
      disableLocalAuth       = true
      allowProjectManagement = true
    }
  }

  response_export_values = ["properties.endpoint", "identity.principalId"]

  lifecycle {
    ignore_changes = [identity]
  }
}

# Default project in each team's Foundry resource
# Named after the team with isDefault=true for visibility in new Foundry portal
resource "azapi_resource" "foundry_project" {
  for_each = {
    for team_name, team in local.teams :
    team_name => team
    if team.foundry_enabled
  }

  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = each.value.name
  parent_id = azapi_resource.foundry_resource[each.key].id

  # Disable schema validation for newer API properties
  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind     = "AIServices"
    location = local.platform.location
    properties = {
      isDefault   = true
      description = "AI project for team ${each.value.name}"
    }
  }

  response_export_values = ["properties.endpoints", "identity.principalId"]

  lifecycle {
    ignore_changes = [identity]
  }
}

# APIM Connection for each Foundry project
# Allows developers to use the Foundry playground with APIM-governed model access
# Uses static model list based on team's requested models
resource "azapi_resource" "foundry_apim_connection" {
  for_each = {
    for team_name, team in local.teams :
    team_name => team
    if team.foundry_enabled && length(team.foundry_models) > 0
  }

  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = "apim-${each.value.name}"
  parent_id = azapi_resource.foundry_project[each.key].id

  # Disable schema validation for newer API
  schema_validation_enabled = false

  body = {
    properties = {
      category = "ApiManagement"
      target   = "${local.platform.apim_gateway_url}/openai"
      authType = "ApiKey"
      credentials = {
        key = data.azapi_resource_action.subscription_keys[each.key].output.primaryKey
      }
      metadata = {
        # deploymentInPath controls how model name is passed to APIM
        deploymentInPath    = "true"
        # API version for OpenAI inference calls
        inferenceAPIVersion = "2024-10-21"
        # Static list of models available through this connection
        models = jsonencode([
          for model in each.value.foundry_models : {
            name = model.name
            properties = {
              model = {
                name    = model.name
                version = ""
                format  = "OpenAI"
              }
            }
          }
        ])
      }
    }
  }

  # Ignore isSharedToAll as API doesn't properly support updates
  lifecycle {
    ignore_changes = [body]
  }

  depends_on = [
    azapi_resource.foundry_project,
    azurerm_api_management_product_api.openai
  ]
}
