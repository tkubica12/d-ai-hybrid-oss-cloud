# APIM configuration for KAITO models
# Creates backend, API, and operations for platform-managed OSS models
# Uses internal LoadBalancer IPs (VNet-routable) since APIM is VNet-integrated

# APIM Backend per KAITO model (each model has its own LoadBalancer service)
resource "azapi_resource" "apim_kaito_backend" {
  for_each = local.kaito_models

  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name      = "kaito-${each.key}"
  parent_id = local.platform.apim_id

  body = {
    properties = {
      title       = "KAITO ${each.value.display_name}"
      description = "Backend for ${each.value.display_name} KAITO model"
      protocol    = "http"
      # Use VNet-internal LoadBalancer IP (APIM is VNet-integrated)
      url = "http://${each.value.service_ip}"
    }
  }
}

# APIM API for KAITO models (OpenAI-compatible)
resource "azapi_resource" "apim_kaito_api" {
  count = length(local.kaito_models) > 0 ? 1 : 0

  type      = "Microsoft.ApiManagement/service/apis@2024-06-01-preview"
  name      = "kaito-openai"
  parent_id = local.platform.apim_id

  body = {
    properties = {
      displayName = "KAITO OpenAI Compatible API"
      description = "OpenAI-compatible API for platform-managed OSS models"
      path        = "kaito"
      protocols   = ["https"]
      subscriptionRequired = true
      subscriptionKeyParameterNames = {
        header = "api-key"
        query  = "api-key"
      }
    }
  }
}

# Chat completions operation per KAITO model
resource "azapi_resource" "apim_kaito_chat_operation" {
  for_each = local.kaito_models

  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "${each.key}-chat-completions"
  parent_id = azapi_resource.apim_kaito_api[0].id

  body = {
    properties = {
      displayName = "${each.value.display_name} - Chat Completions"
      description = "Create a chat completion for ${each.value.display_name}"
      method      = "POST"
      urlTemplate = "/deployments/${each.key}/chat/completions"
      request = {
        headers = []
        queryParameters = [
          {
            name     = "api-version"
            type     = "string"
            required = false
          }
        ]
      }
      responses = [
        {
          statusCode  = 200
          description = "Success"
        }
      ]
    }
  }
}

# Completions operation per KAITO model
resource "azapi_resource" "apim_kaito_completions_operation" {
  for_each = local.kaito_models

  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "${each.key}-completions"
  parent_id = azapi_resource.apim_kaito_api[0].id

  body = {
    properties = {
      displayName = "${each.value.display_name} - Completions"
      description = "Create a completion for ${each.value.display_name}"
      method      = "POST"
      urlTemplate = "/deployments/${each.key}/completions"
      request = {
        headers = []
        queryParameters = [
          {
            name     = "api-version"
            type     = "string"
            required = false
          }
        ]
      }
      responses = [
        {
          statusCode  = 200
          description = "Success"
        }
      ]
    }
  }
}

# Policy to route chat completions to KAITO backend via Gateway API path
resource "azapi_resource" "apim_kaito_chat_policy" {
  for_each = local.kaito_models

  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview"
  name      = "policy"
  parent_id = azapi_resource.apim_kaito_chat_operation[each.key].id

  body = {
    properties = {
      format = "xml"
      value  = <<-XML
<policies>
  <inbound>
    <!-- Set model-name for product policy authorization check -->
    <set-variable name="model-name" value="${each.key}" />
    <base />
    <set-backend-service backend-id="kaito-${each.key}" />
    <!-- Route directly to vLLM chat completions endpoint -->
    <rewrite-uri template="/v1/chat/completions" />
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

  depends_on = [azapi_resource.apim_kaito_backend]
}

# Policy for completions operation
resource "azapi_resource" "apim_kaito_completions_policy" {
  for_each = local.kaito_models

  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview"
  name      = "policy"
  parent_id = azapi_resource.apim_kaito_completions_operation[each.key].id

  body = {
    properties = {
      format = "xml"
      value  = <<-XML
<policies>
  <inbound>
    <!-- Set model-name for product policy authorization check -->
    <set-variable name="model-name" value="${each.key}" />
    <base />
    <set-backend-service backend-id="kaito-${each.key}" />
    <!-- Route directly to vLLM completions endpoint -->
    <rewrite-uri template="/v1/completions" />
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

  depends_on = [azapi_resource.apim_kaito_backend]
}

# Associate KAITO API with team products that have KAITO models
resource "azurerm_api_management_product_api" "kaito" {
  for_each = {
    for team_name, team in local.teams : team_name => team
    if length(team.kaito_models) > 0 && length(local.kaito_models) > 0
  }

  api_name            = "kaito-openai"
  product_id          = "product-${each.value.name}"
  api_management_name = local.platform.apim_name
  resource_group_name = local.platform.resource_group_name

  depends_on = [
    azapi_resource.apim_product,
    azapi_resource.apim_kaito_api
  ]
}
