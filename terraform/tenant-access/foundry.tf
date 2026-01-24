# Foundry Projects for each team
# Creates isolated project space within the shared Foundry resource
# Note: Uses azapi as azurerm doesn't support CognitiveServices/accounts/projects

resource "azapi_resource" "foundry_project" {
  for_each = {
    for team_name, team in local.teams :
    team_name => team
    if team.foundry_enabled
  }

  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = "project-${each.value.name}"
  parent_id = local.platform.foundry_id

  # Disable schema validation for newer API properties
  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind     = "AIServices"
    location = local.platform.location
    properties = {
      description = "AI project for team ${each.value.name}"
    }
  }

  response_export_values = ["properties.endpoints", "identity.principalId"]

  lifecycle {
    ignore_changes = [identity]
  }
}
