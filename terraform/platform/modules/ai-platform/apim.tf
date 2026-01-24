# Azure API Management v2 Standard tier
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
    }
  }

  response_export_values = ["properties.gatewayUrl", "identity.principalId"]
}

# APIM Backend for Foundry OpenAI endpoint
resource "azapi_resource" "apim_backend_foundry" {
  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name      = "foundry-backend"
  parent_id = azapi_resource.apim.id

  body = {
    properties = {
      title       = "Azure AI Foundry"
      description = "Backend for Azure AI Foundry OpenAI endpoint"
      url         = "${azapi_resource.foundry.output.properties.endpoint}openai"
      protocol    = "http"
      tls = {
        validateCertificateChain = true
        validateCertificateName  = true
      }
    }
  }

  depends_on = [azapi_resource.apim, azapi_resource.foundry]
}

# APIM API definition for OpenAI-compatible endpoint
resource "azapi_resource" "apim_api_openai" {
  type      = "Microsoft.ApiManagement/service/apis@2024-06-01-preview"
  name      = "openai-api"
  parent_id = azapi_resource.apim.id

  body = {
    properties = {
      displayName          = "OpenAI API"
      description          = "OpenAI-compatible API for AI models"
      path                 = "openai"
      protocols            = ["https"]
      subscriptionRequired = true
      subscriptionKeyParameterNames = {
        header = "api-key"
        query  = "api-key"
      }
      serviceUrl = "${azapi_resource.foundry.output.properties.endpoint}openai"
    }
  }

  depends_on = [azapi_resource.apim, azapi_resource.foundry]
}

# API Operations - Chat Completions
resource "azapi_resource" "apim_api_chat" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "chat-completions"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      displayName = "Chat Completions"
      description = "Creates a completion for the chat message"
      method      = "POST"
      urlTemplate = "/deployments/{deployment-id}/chat/completions"
      templateParameters = [
        {
          name        = "deployment-id"
          description = "The deployment name"
          type        = "string"
          required    = true
        }
      ]
      request = {
        queryParameters = [
          {
            name        = "api-version"
            description = "API version"
            type        = "string"
            required    = true
          }
        ]
      }
    }
  }
}

# API Operations - Completions
resource "azapi_resource" "apim_api_completions" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "completions"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      displayName = "Completions"
      description = "Creates a completion for the prompt"
      method      = "POST"
      urlTemplate = "/deployments/{deployment-id}/completions"
      templateParameters = [
        {
          name        = "deployment-id"
          description = "The deployment name"
          type        = "string"
          required    = true
        }
      ]
      request = {
        queryParameters = [
          {
            name        = "api-version"
            description = "API version"
            type        = "string"
            required    = true
          }
        ]
      }
    }
  }
}

# API Operations - Embeddings
resource "azapi_resource" "apim_api_embeddings" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "embeddings"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      displayName = "Embeddings"
      description = "Creates an embedding vector"
      method      = "POST"
      urlTemplate = "/deployments/{deployment-id}/embeddings"
      templateParameters = [
        {
          name        = "deployment-id"
          description = "The deployment name"
          type        = "string"
          required    = true
        }
      ]
      request = {
        queryParameters = [
          {
            name        = "api-version"
            description = "API version"
            type        = "string"
            required    = true
          }
        ]
      }
    }
  }
}

# API Policy for backend routing
resource "azapi_resource" "apim_api_policy" {
  type      = "Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview"
  name      = "policy"
  parent_id = azapi_resource.apim_api_openai.id

  body = {
    properties = {
      format = "xml"
      value  = <<-XML
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="foundry-backend" />
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

  lifecycle {
    # Ignore body changes to avoid constant diffs from Azure API normalization
    ignore_changes = [body]
  }
}
