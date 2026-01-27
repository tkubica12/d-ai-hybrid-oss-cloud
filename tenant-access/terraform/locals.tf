# Load and parse tenant access request YAML files
# Each team's request is in tenant-access/config/<team-name>/access.yaml

locals {
  # Find all team directories in tenant config
  team_dirs = fileset(var.tenant_config_path, "*/access.yaml")

  # Parse each access.yaml file
  team_configs = {
    for file_path in local.team_dirs :
    dirname(file_path) => yamldecode(file(
      "${var.tenant_config_path}/${file_path}"
    ))
  }

  # Flatten for easier iteration - updated schema with simplified flags
  teams = {
    for team_name, config in local.team_configs :
    team_name => {
      name         = config.team.name
      display_name = try(config.team.displayName, "AI Access - Team ${config.team.name}")
      owner        = config.team.owner
      cost_center  = try(config.team.costCenter, "")

      # Foundry models - no more enabled flag, presence implies enabled
      foundry_models = [
        for model in try(config.models.foundry, []) : {
          name              = model.name
          tokens_per_minute = try(model.tokensPerMinute, 5000)
          daily_token_quota = try(model.dailyTokenQuota, 100000)
        }
      ]

      # Foundry enabled if any foundry models requested
      foundry_enabled = length(try(config.models.foundry, [])) > 0

      # KAITO models - references to shared platform-managed models
      kaito_models = [
        for model in try(config.models.kaito, []) : {
          name              = model.name
          tokens_per_minute = try(model.tokensPerMinute, 10000)
          daily_token_quota = try(model.dailyTokenQuota, 500000)
        }
      ]
    }
  }

  # Validate KAITO model requests against platform catalog
  kaito_validation_errors = flatten([
    for team_name, team in local.teams : [
      for model in team.kaito_models :
      "Team '${team_name}' requested KAITO model '${model.name}' which is not enabled in platform catalog"
      if !try(local.kaito_catalog[model.name].enabled, false)
    ]
  ])

  # Flatten team-model combinations for per-model resources (Foundry)
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

  # Flatten team-KAITO model combinations
  team_kaito_models = flatten([
    for team_name, team in local.teams : [
      for model in team.kaito_models : {
        key               = "${team_name}-${model.name}"
        team_name         = team_name
        team              = team
        model_name        = model.name
        tokens_per_minute = model.tokens_per_minute
        daily_token_quota = model.daily_token_quota
      }
      if try(local.kaito_catalog[model.name].enabled, false)
    ]
  ])

  team_kaito_models_map = {
    for tm in local.team_kaito_models : tm.key => tm
  }

  # KAITO workspaces (for outputs compatibility)
  kaito_workspaces = []
}

# Validation check - fail if invalid KAITO models requested
resource "terraform_data" "validate_kaito_models" {
  count = length(local.kaito_validation_errors) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.kaito_validation_errors) == 0
      error_message = join("\n", local.kaito_validation_errors)
    }
  }
}
