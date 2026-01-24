# Team access outputs
output "teams" {
  description = "Map of team configurations"
  value = {
    for team_name, team in local.teams :
    team_name => {
      name              = team.name
      display_name      = team.display_name
      namespace         = kubernetes_namespace_v1.team[team_name].metadata[0].name
      apim_product_name = azapi_resource.apim_product[team_name].name
      foundry_project   = try(azapi_resource.foundry_project[team_name].name, null)
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
