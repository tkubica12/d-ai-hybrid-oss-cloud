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

  # Flatten for easier iteration
  teams = {
    for team_name, config in local.team_configs :
    team_name => {
      name             = config.team.name
      display_name     = try(config.team.displayName, "AI Access - Team ${config.team.name}")
      owner            = config.team.owner
      cost_center      = try(config.team.costCenter, "")
      foundry_enabled  = try(config.models.foundry.enabled, true)
      foundry_models   = try(config.models.foundry.models, [])
      kaito_enabled    = try(config.models.kaito.enabled, false)
      kaito_workspaces = try(config.models.kaito.workspaces, [])
      tokens_per_minute = try(config.limits.tokensPerMinute, 5000)
      daily_token_quota = try(config.limits.dailyTokenQuota, 100000)
    }
  }
}
