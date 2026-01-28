# Azure API Management v2 Standard tier with VNet integration
# Uses azapi for access to the latest API version with v2 SKU support
resource "azapi_resource" "apim" {
  type      = "Microsoft.ApiManagement/service@2024-06-01-preview"
  name      = local.apim_name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku = {
      name     = "StandardV2"
      capacity = 1
    }
    properties = {
      publisherEmail = var.apim_publisher_email
      publisherName  = var.apim_publisher_name
      # VNet integration for accessing internal AKS LoadBalancer services
      virtualNetworkType = "External"
      virtualNetworkConfiguration = {
        subnetResourceId = var.apim_subnet_id
      }
    }
  }

  response_export_values = ["properties.gatewayUrl", "identity.principalId"]
}

# APIM Backend for Foundry OpenAI v1 endpoint
# Uses the OpenAI-compatible v1 endpoint which accepts model in request body
# This greatly simplifies the APIM policy (no URL rewriting needed)
resource "azapi_resource" "apim_backend_foundry" {
  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name      = "foundry-backend"
  parent_id = azapi_resource.apim.id

  body = {
    properties = {
      title       = "Azure AI Foundry"
      description = "Backend for Azure AI Foundry OpenAI v1 compatible endpoint"
      # OpenAI v1 endpoint format: https://<resource>.openai.azure.com/openai/v1
      # This endpoint uses model name in request body (like standard OpenAI API)
      # No api-version query parameter needed (implicit versioning)
      url      = "${trimsuffix(azapi_resource.foundry.output.properties.endpoint, "/")}/openai/v1"
      protocol = "http"
      tls = {
        validateCertificateChain = true
        validateCertificateName  = true
      }
      # Circuit breaker to handle 429 responses from Azure OpenAI with Retry-After header
      circuitBreaker = {
        rules = [
          {
            name = "openai-throttle-breaker"
            failureCondition = {
              count    = 3
              interval = "PT1M"
              statusCodeRanges = [
                {
                  min = 429
                  max = 429
                },
                {
                  min = 500
                  max = 599
                }
              ]
            }
            tripDuration     = "PT30S"
            acceptRetryAfter = true
          }
        ]
      }
    }
  }

  depends_on = [azapi_resource.apim, azapi_resource.foundry]
}

# APIM API definition for OpenAI-compatible v1 endpoint
# Uses the OpenAI v1 API format where model is in request body, not URL
# With the v1 Foundry endpoint, no URL rewriting is needed - requests pass through directly
resource "azapi_resource" "apim_api_openai" {
  type      = "Microsoft.ApiManagement/service/apis@2024-06-01-preview"
  name      = "openai-api"
  parent_id = azapi_resource.apim.id

  body = {
    properties = {
      displayName          = "OpenAI API"
      description          = "OpenAI-compatible v1 API for AI models. Uses standard OpenAI SDK format with model in request body."
      path                 = "openai/v1"
      protocols            = ["https"]
      subscriptionRequired = true
      subscriptionKeyParameterNames = {
        header = "api-key"
        query  = "api-key"
      }
      # serviceUrl not set - backend reference is used instead via set-backend-service policy
    }
  }

  depends_on = [azapi_resource.apim, azapi_resource.foundry]
}

# API Operations - Chat Completions (OpenAI v1 format)
resource "azapi_resource" "apim_api_chat" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "chat-completions"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      displayName = "Chat Completions"
      description = "Creates a completion for the chat message"
      method      = "POST"
      urlTemplate = "/chat/completions"
    }
  }
}

# API Operations - Completions (OpenAI v1 format)
resource "azapi_resource" "apim_api_completions" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "completions"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      displayName = "Completions"
      description = "Creates a completion for the prompt"
      method      = "POST"
      urlTemplate = "/completions"
    }
  }
}

# API Operations - Embeddings (OpenAI v1 format)
resource "azapi_resource" "apim_api_embeddings" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "embeddings"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      displayName = "Embeddings"
      description = "Creates an embedding vector"
      method      = "POST"
      urlTemplate = "/embeddings"
    }
  }
}

# API Operations - List Models (OpenAI v1 format)
# Required for OpenAI SDK model discovery
resource "azapi_resource" "apim_api_models" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "list-models"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      displayName = "List Models"
      description = "Lists available models"
      method      = "GET"
      urlTemplate = "/models"
    }
  }
}

# API Policy for backend routing with managed identity auth
# With the OpenAI v1 endpoint, no URL rewriting is needed - requests pass through directly
# The Foundry /openai/v1 endpoint handles routing based on model name in request body
resource "azapi_resource" "apim_api_policy" {
  type      = "Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview"
  name      = "policy"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      format = "rawxml"
      value  = <<-XML
<policies>
    <inbound>
        <base />
        <!-- Route to Foundry backend (configured with /openai/v1 endpoint) -->
        <set-backend-service backend-id="foundry-backend" />
        <!-- Authenticate using APIM managed identity -->
        <!-- The managed identity must have 'Cognitive Services OpenAI User' role on the Foundry resource -->
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
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

  depends_on = [azapi_resource.apim_backend_foundry]
}
