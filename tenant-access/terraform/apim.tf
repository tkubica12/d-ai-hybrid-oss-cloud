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
# Using azurerm resource as it supports proper lifecycle management
resource "azurerm_api_management_product_api" "openai" {
  for_each = local.teams

  api_name            = local.platform.openai_api_name
  product_id          = "product-${each.value.name}"
  api_management_name = local.platform.apim_name
  resource_group_name = local.platform.resource_group_name

  depends_on = [azapi_resource.apim_product]
}

# Generate per-model rate limiting policy XML for each team
# Includes both Foundry and KAITO models
locals {
  team_policies = {
    for team_name, team in local.teams : team_name => {
      foundry_models = team.foundry_models
      kaito_models   = team.kaito_models
      policy_xml     = <<-XML
<policies>
  <inbound>
    <base />
    <!-- Per-model LLM token-based rate limiting -->
    <!-- Extract model name from request body (OpenAI v1 format) -->
    <set-variable name="model-name" value="@{
      try {
        var body = context.Request.Body.As&lt;JObject&gt;(preserveContent: true);
        return body?.GetValue("model")?.ToString() ?? "";
      } catch {
        return "";
      }
    }" />
    <choose>
${join("\n", [
  for model in team.foundry_models : <<-CONDITION
      <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;model-name&quot;) == &quot;${model.name}&quot;)">
        <llm-token-limit
          counter-key="@(context.Subscription.Id + &quot;-${model.name}&quot;)"
          tokens-per-minute="${model.tokens_per_minute}"
          token-quota="${model.daily_token_quota}"
          token-quota-period="Daily"
          estimate-prompt-tokens="true"
          remaining-tokens-header-name="x-ratelimit-remaining-tokens"
          remaining-quota-tokens-header-name="x-quota-remaining-tokens"
          tokens-consumed-header-name="x-tokens-consumed" />
      </when>
CONDITION
])}
${join("\n", [
  for model in team.kaito_models : <<-CONDITION
      <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;model-name&quot;) == &quot;${model.name}&quot;)">
        <llm-token-limit
          counter-key="@(context.Subscription.Id + &quot;-kaito-${model.name}&quot;)"
          tokens-per-minute="${model.tokens_per_minute}"
          token-quota="${model.daily_token_quota}"
          token-quota-period="Daily"
          estimate-prompt-tokens="true"
          remaining-tokens-header-name="x-ratelimit-remaining-tokens"
          remaining-quota-tokens-header-name="x-quota-remaining-tokens"
          tokens-consumed-header-name="x-tokens-consumed" />
      </when>
CONDITION
  if try(local.kaito_catalog[model.name].enabled, false)
])}
      <otherwise>
        <!-- Default: deny access to models not in team's allowed list -->
        <return-response>
          <set-status code="403" reason="Model not authorized" />
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-body>@{
            return new JObject(
              new JProperty("error", new JObject(
                new JProperty("code", "ModelNotAuthorized"),
                new JProperty("message", "Your subscription does not have access to this model.")
              ))
            ).ToString();
          }</set-body>
        </return-response>
      </otherwise>
    </choose>
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
}

# Product Policy with per-model LLM token-based rate limiting
resource "azurerm_api_management_product_policy" "main" {
  for_each = local.teams

  product_id          = "product-${each.value.name}"
  api_management_name = local.platform.apim_name
  resource_group_name = local.platform.resource_group_name
  xml_content         = local.team_policies[each.key].policy_xml

  depends_on = [azapi_resource.apim_product]
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
