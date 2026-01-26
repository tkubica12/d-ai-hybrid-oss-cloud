# Load and parse developer access request YAML files
# Each team's request is in developer-requests/<team-name>/access.yaml

locals {
  # Find all team directories in developer-requests
  team_dirs = fileset(var.developer_requests_path, "*/access.yaml")

  # Parse each access.yaml file
  team_configs = {
    for file_path in local.team_dirs :
    dirname(file_path) => yamldecode(file(
      "${var.developer_requests_path}/${file_path}"
    ))
  }

  # Flatten for easier iteration - now with per-model limits
  teams = {
    for team_name, config in local.team_configs :
    team_name => {
      name             = config.team.name
      display_name     = try(config.team.displayName, "AI Access - Team ${config.team.name}")
      owner            = config.team.owner
      cost_center      = try(config.team.costCenter, "")
      foundry_enabled  = try(config.models.foundry.enabled, true)
      foundry_models = [
        for model in try(config.models.foundry.models, []) : {
          name              = model.name
          tokens_per_minute = try(model.tokensPerMinute, 5000)
          daily_token_quota = try(model.dailyTokenQuota, 100000)
        }
      ]
      kaito_enabled    = try(config.models.kaito.enabled, false)
      kaito_workspaces = try(config.models.kaito.workspaces, [])
    }
  }

  # Flatten team-model combinations for per-model resources
  team_models = flatten([
    for team_name, team in local.teams : [
      for model in team.foundry_models : {
        key               = "${team_name}-${model.name}"
        team_name         = team_name
        team              = team
        model_name        = model.name
        tokens_per_minute = model.tokens_per_minute
        daily_token_quota = model.daily_token_quota
      }
    ]
  ])

  # Convert to map for for_each
  team_models_map = {
    for tm in local.team_models : tm.key => tm
  }
}
