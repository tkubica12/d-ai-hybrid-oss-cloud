# KAITO Workspaces for teams requesting open-source models
# Deploys GPU-powered inference workloads via KAITO operator

# Flatten workspaces for iteration
# Each workspace needs team context for proper naming and labeling
locals {
  kaito_workspaces = flatten([
    for team_name, team in local.teams : [
      for workspace in team.kaito_workspaces : {
        key           = "${team_name}-${workspace.name}"
        team_name     = team.name
        workspace     = workspace
        instance_type = workspace.instanceType
        preset_name   = workspace.name
      }
    ] if team.kaito_enabled && length(team.kaito_workspaces) > 0
  ])
}

# Deploy KAITO workspaces using helm_release with raw templates
# This is more reliable than kubernetes_manifest for CRDs
resource "helm_release" "kaito_workspace" {
  for_each = { for ws in local.kaito_workspaces : ws.key => ws }

  name       = "kaito-${each.value.team_name}-${each.value.preset_name}"
  namespace  = "default"
  repository = null
  chart      = "${path.module}/../../charts/developer-access"

  # Pass all configuration via values (Helm provider 3.x syntax)
  values = [
    yamlencode({
      team = {
        name = each.value.team_name
      }
      kaito = {
        enabled = true
        workspaces = [
          {
            name         = each.value.preset_name
            instanceType = each.value.instance_type
          }
        ]
      }
    })
  ]

  # Long timeout for GPU node provisioning
  timeout = 1800

  # Allow workspace creation even if errors occur
  atomic = false
}
