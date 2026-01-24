# Kubernetes secrets for each team
# Contains APIM API key for accessing AI services

resource "kubernetes_namespace_v1" "team" {
  for_each = local.teams

  metadata {
    name = "team-${each.value.name}"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "ai.contoso.com/team"          = each.value.name
    }
    annotations = {
      "ai.contoso.com/owner"       = each.value.owner
      "ai.contoso.com/cost-center" = each.value.cost_center
    }
  }
}

resource "kubernetes_secret_v1" "ai_credentials" {
  for_each = local.teams

  metadata {
    name      = "ai-gateway-credentials"
    namespace = kubernetes_namespace_v1.team[each.key].metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "ai.contoso.com/team"          = each.value.name
    }
  }

  data = {
    "APIM_GATEWAY_URL" = local.platform.apim_gateway_url
    "APIM_API_KEY"     = data.azapi_resource_action.subscription_keys[each.key].output.primaryKey
    "OPENAI_API_BASE"  = "${local.platform.apim_gateway_url}/openai"
    "OPENAI_API_KEY"   = data.azapi_resource_action.subscription_keys[each.key].output.primaryKey
  }

  type = "Opaque"
}
