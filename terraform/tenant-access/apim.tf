# APIM Product for each team
# Provides a container for API access with associated policies and subscriptions

resource "azapi_resource" "apim_product" {
  for_each = local.teams

  type      = "Microsoft.ApiManagement/service/products@2024-06-01-preview"
  name      = "product-${each.value.name}"
  parent_id = local.platform.apim_id

  body = {
    properties = {
      displayName          = each.value.display_name
      description          = "AI model access for team ${each.value.name}"
      state                = "published"
      subscriptionRequired = true
      approvalRequired     = false
      subscriptionsLimit   = 5
    }
  }
}

# Associate OpenAI API with each team's product
resource "azapi_resource" "apim_product_api" {
  for_each = local.teams

  type      = "Microsoft.ApiManagement/service/products/apiLinks@2024-06-01-preview"
  name      = "link-${local.platform.openai_api_name}"
  parent_id = azapi_resource.apim_product[each.key].id

  body = {
    properties = {
      apiId = "${local.platform.apim_id}/apis/${local.platform.openai_api_name}"
    }
  }
}

# Product Policy with LLM token-based rate limiting
resource "azapi_resource" "apim_product_policy" {
  for_each = local.teams

  type      = "Microsoft.ApiManagement/service/products/policies@2024-06-01-preview"
  name      = "policy"
  parent_id = azapi_resource.apim_product[each.key].id

  body = {
    properties = {
      format = "xml"
      value  = <<-XML
<policies>
  <inbound>
    <base />
    <!-- LLM token-based rate limiting and quota -->
    <llm-token-limit
      counter-key="@(context.Subscription.Id)"
      tokens-per-minute="${each.value.tokens_per_minute}"
      token-quota="${each.value.daily_token_quota}"
      token-quota-period="Daily"
      estimate-prompt-tokens="true"
      remaining-tokens-header-name="x-ratelimit-remaining-tokens"
      remaining-quota-tokens-header-name="x-quota-remaining-tokens"
      tokens-consumed-header-name="x-tokens-consumed" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
      XML
    }
  }

  lifecycle {
    ignore_changes = [body]
  }
}

# Subscription for each team - generates the API key
resource "azapi_resource" "apim_subscription" {
  for_each = local.teams

  type      = "Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview"
  name      = "sub-${each.value.name}"
  parent_id = local.platform.apim_id

  body = {
    properties = {
      displayName = "Subscription for team ${each.value.name}"
      scope       = "${local.platform.apim_id}/products/${azapi_resource.apim_product[each.key].name}"
      state       = "active"
    }
  }

  response_export_values = ["properties.primaryKey", "properties.secondaryKey"]
}
