# Team access outputs
output "teams" {
  description = "Map of team configurations"
  value = {
    for team_name, team in local.teams :
    team_name => {
      name               = team.name
      display_name       = team.display_name
      apim_product_name  = azapi_resource.apim_product[team_name].name
      foundry_resource   = try(azapi_resource.foundry_resource[team_name].name, null)
      foundry_endpoint   = try(azapi_resource.foundry_resource[team_name].output.properties.endpoint, null)
      foundry_project    = try(azapi_resource.foundry_project[team_name].name, null)
      apim_connection    = try(azapi_resource.foundry_apim_connection[team_name].name, null)
      kaito_workspaces = [
        for ws in local.kaito_workspaces :
        ws.preset_name if ws.team_name == team.name
      ]
    }
  }
}

output "apim_gateway_url" {
  description = "APIM Gateway URL for API access"
  value       = local.platform.apim_gateway_url
}

# Sensitive outputs - API keys per team
output "team_api_keys" {
  description = "API keys for each team (sensitive)"
  value = {
    for team_name, team in local.teams :
    team_name => {
      primary_key   = data.azapi_resource_action.subscription_keys[team_name].output.primaryKey
      secondary_key = data.azapi_resource_action.subscription_keys[team_name].output.secondaryKey
    }
  }
  sensitive = true
}
