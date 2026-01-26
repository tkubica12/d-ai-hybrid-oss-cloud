# Implementation Plan: Shared KAITO Models with Centralized Deployment

## Overview

This plan transitions from per-team KAITO workspaces to centralized, platform-managed OSS model deployments with quota-based access control via APIM.

## Architecture Changes

```
BEFORE (Per-Team Deployment):
┌─────────────────────────────────────────────────────────────────────┐
│ tenant-access terraform                                             │
│   └── Deploys KAITO Workspace per team request                     │
│        • team-alpha requests phi-4 → deploys workspace-alpha-phi-4 │
│        • team-beta requests phi-4 → deploys workspace-beta-phi-4   │
│        → 2 GPU VMs running same model!                              │
└─────────────────────────────────────────────────────────────────────┘

AFTER (Shared Platform Deployment):
┌─────────────────────────────────────────────────────────────────────┐
│ platform terraform                                                  │
│   └── Reads model_catalog.yaml                                      │
│        └── Deploys KAITO Workspace for enabled models              │
│             • phi-4 (enabled) → workspace-phi-4 (1 GPU VM)         │
│             • mistral-7b (enabled) → workspace-mistral-7b          │
│        └── Captures service endpoints (ClusterIP/Ingress)          │
│        └── Outputs endpoints for tenant-access                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ tenant-access terraform                                             │
│   └── Reads team access.yaml                                        │
│        └── Validates requested models exist in catalog (enabled)   │
│        └── Creates APIM backend pointing to KAITO service          │
│        └── Creates APIM API for KAITO models (OpenAI-compatible)   │
│        └── Creates APIM Product with token limits per team         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Model Catalog Definition

### File: `terraform/platform/model_catalog.yaml`

```yaml
# Platform-managed OSS Model Catalog
# Models with enabled: true are deployed centrally via KAITO
# Teams can only request access to enabled models

kaito_models:
  - name: phi-4
    displayName: "Microsoft Phi-4"
    description: "High-performance small language model from Microsoft"
    preset: phi-4
    instanceType: Standard_NC24ads_A100_v4
    enabled: true
    # Estimated capacity for quota planning
    estimatedTokensPerMinute: 500000
    
  - name: phi-4-mini
    displayName: "Microsoft Phi-4 Mini"
    description: "Compact version of Phi-4 for lighter workloads"
    preset: phi-4-mini
    instanceType: Standard_NC6s_v3
    enabled: true
    estimatedTokensPerMinute: 200000
    
  - name: mistral-7b
    displayName: "Mistral 7B Instruct"
    description: "Mistral AI 7B parameter instruction-tuned model"
    preset: mistral-7b-instruct
    instanceType: Standard_NC24ads_A100_v4
    enabled: false  # Available but not deployed - request to enable
    estimatedTokensPerMinute: 600000
    
  - name: llama-3-8b
    displayName: "Meta Llama 3 8B"
    description: "Meta's Llama 3 8B parameter model"
    preset: llama-3-8b-instruct
    instanceType: Standard_NC24ads_A100_v4
    enabled: false
    estimatedTokensPerMinute: 550000
    
  - name: deepseek-r1
    displayName: "DeepSeek R1"
    description: "DeepSeek reasoning model"
    preset: deepseek-r1-distill-llama-8b
    instanceType: Standard_NC24ads_A100_v4
    enabled: false
    estimatedTokensPerMinute: 400000
```

---

## Phase 2: Platform Terraform Changes

### 2.1 New File: `terraform/platform/kaito.tf`

```terraform
# Load model catalog
locals {
  model_catalog = yamldecode(file("${path.module}/model_catalog.yaml"))
  
  # Filter to enabled models only
  enabled_kaito_models = {
    for model in local.model_catalog.kaito_models :
    model.name => model
    if model.enabled
  }
}

# Deploy KAITO workspace for each enabled model
resource "kubernetes_manifest" "kaito_workspace" {
  for_each = local.enabled_kaito_models

  manifest = {
    apiVersion = "kaito.sh/v1beta1"
    kind       = "Workspace"
    metadata = {
      name      = "workspace-${each.key}"
      namespace = "default"
      labels = {
        "platform.ai/model"      = each.key
        "platform.ai/managed-by" = "platform-terraform"
      }
    }
    resource = {
      instanceType = each.value.instanceType
      labelSelector = {
        matchLabels = {
          apps = each.key
        }
      }
    }
    inference = {
      preset = {
        name = each.value.preset
      }
    }
  }

  # Wait for CRD to be available
  depends_on = [module.aks_kaito]
}
```

### 2.1b New File: `terraform/platform/gateway.tf`

```terraform
# Gateway API for routing to KAITO models
# Exposes single internal LoadBalancer IP that APIM can reach

# Gateway with internal LoadBalancer
resource "kubernetes_manifest" "kaito_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "kaito-gateway"
      namespace = "default"
      annotations = {
        # Request internal LoadBalancer with specific subnet
        "alb.networking.azure.io/alb-frontend-type" = "internal"
      }
    }
    spec = {
      gatewayClassName = "azure-alb-internal"
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = {
              from = "Same"
            }
          }
        }
      ]
    }
  }

  depends_on = [module.aks_kaito]
}

# HTTPRoute per enabled KAITO model
resource "kubernetes_manifest" "kaito_httproute" {
  for_each = local.enabled_kaito_models

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "kaito-${each.key}"
      namespace = "default"
    }
    spec = {
      parentRefs = [
        {
          name = "kaito-gateway"
        }
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/${each.key}"
              }
            }
          ]
          backendRefs = [
            {
              name = "workspace-${each.key}"
              port = 80
            }
          ]
          filters = [
            {
              type = "URLRewrite"
              urlRewrite = {
                path = {
                  type               = "ReplacePrefixMatch"
                  replacePrefixMatch = "/v1"
                }
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.kaito_gateway,
    kubernetes_manifest.kaito_workspace
  ]
}

# Wait for Gateway to get an IP address
data "kubernetes_resource" "kaito_gateway_status" {
  api_version = "gateway.networking.k8s.io/v1"
  kind        = "Gateway"

  metadata {
    name      = "kaito-gateway"
    namespace = "default"
  }

  depends_on = [kubernetes_manifest.kaito_gateway]
}

locals {
  # Extract Gateway IP from status
  kaito_gateway_ip = try(
    data.kubernetes_resource.kaito_gateway_status.object.status.addresses[0].value,
    null
  )
}
```

### 2.2 Platform Runtime Output: `terraform/platform/platform-runtime.yaml`

Instead of terraform_remote_state, platform terraform generates a YAML file with runtime information:

```yaml
# Auto-generated by platform terraform - DO NOT EDIT MANUALLY
# Generated at: 2026-01-26T10:30:00Z

platform:
  resource_group_name: rg-ai-platform-demo
  resource_group_id: /subscriptions/.../resourceGroups/rg-ai-platform-demo
  location: swedencentral

apim:
  id: /subscriptions/.../Microsoft.ApiManagement/service/apim-ai-platform
  name: apim-ai-platform
  gateway_url: https://apim-ai-platform.azure-api.net
  openai_api_name: azure-openai

aks:
  id: /subscriptions/.../managedClusters/aks-ai-platform
  name: aks-ai-platform
  
kaito:
  gateway_ip: 10.10.5.100  # Internal IP of Gateway API
  models:
    phi-4:
      name: phi-4
      display_name: "Microsoft Phi-4"
      enabled: true
      workspace_name: workspace-phi-4
      endpoint_path: /phi-4
      status: Ready  # or Provisioning, Failed
    phi-4-mini:
      name: phi-4-mini
      display_name: "Microsoft Phi-4 Mini"
      enabled: true
      workspace_name: workspace-phi-4-mini
      endpoint_path: /phi-4-mini
      status: Ready

foundry:
  account_id: /subscriptions/.../accounts/aifoundry-ai-platform
  account_name: aifoundry-ai-platform
  models:
    gpt-4.1:
      name: gpt-4.1
      deployment_name: gpt-4.1
      endpoint: https://aifoundry-ai-platform.openai.azure.com
    gpt-5-mini:
      name: gpt-5-mini
      deployment_name: gpt-5-mini
      endpoint: https://aifoundry-ai-platform.openai.azure.com
```

### Terraform Generation Code

```terraform
# Generate platform-runtime.yaml for tenant-access consumption
resource "local_file" "platform_runtime" {
  filename = "${path.module}/platform-runtime.yaml"
  content  = yamlencode({
    # Header
    _generated_at = timestamp()
    _warning      = "Auto-generated by platform terraform - DO NOT EDIT MANUALLY"
    
    platform = {
      resource_group_name = azurerm_resource_group.main.name
      resource_group_id   = azurerm_resource_group.main.id
      location            = var.location
    }
    
    apim = {
      id              = module.ai_platform.apim_id
      name            = module.ai_platform.apim_name
      gateway_url     = module.ai_platform.apim_gateway_url
      openai_api_name = "azure-openai"
    }
    
    aks = {
      id   = module.aks_kaito.cluster_id
      name = module.aks_kaito.cluster_name
    }
    
    kaito = {
      gateway_ip = data.kubernetes_service.kaito_gateway.status[0].load_balancer[0].ingress[0].ip
      models = {
        for name, model in local.enabled_kaito_models :
        name => {
          name           = name
          display_name   = model.displayName
          enabled        = true
          workspace_name = "workspace-${name}"
          endpoint_path  = "/${name}"
          status         = try(data.kubernetes_resource.kaito_workspace_status[name].object.status.conditions[0].type, "Unknown")
        }
      }
    }
    
    foundry = {
      account_id   = module.ai_platform.foundry_account_id
      account_name = module.ai_platform.foundry_account_name
      models = {
        for model in var.foundry_models :
        model.name => {
          name            = model.name
          deployment_name = model.name
          endpoint        = module.ai_platform.foundry_endpoint
        }
      }
    }
  })
}
```

---

## Phase 3: Team Access YAML Schema Update

### Updated Schema: `developer-requests/team-alpha/access.yaml`

```yaml
# Team Alpha access configuration
team:
  name: alpha
  displayName: "AI Access - Team Alpha"
  owner: alpha-lead@contoso.com
  costCenter: CC-12345

models:
  # Foundry models (unchanged)
  foundry:
    - name: gpt-4.1
      tokensPerMinute: 10000
      dailyTokenQuota: 1000000
    - name: gpt-5-mini
      tokensPerMinute: 5000
      dailyTokenQuota: 500000

  # KAITO/OSS models - references to platform-managed shared instances
  # No more "enabled" flag - empty list means no access
  kaito:
    - name: phi-4                 # Must exist and be enabled in platform catalog
      tokensPerMinute: 50000      # Team's quota from shared instance
      dailyTokenQuota: 5000000
    - name: phi-4-mini
      tokensPerMinute: 20000
      dailyTokenQuota: 2000000
```

### Key Changes from Current Schema:
1. **Removed**: `foundry.enabled` flag → presence of models implies enabled
2. **Removed**: `kaito.enabled` flag → presence of models implies enabled  
3. **Removed**: `kaito.workspaces` → replaced with `kaito` (list of model references)
4. **Removed**: `instanceType` from team config → managed by platform catalog
5. **Added**: `tokensPerMinute` and `dailyTokenQuota` per KAITO model

---

## Phase 4: Tenant-Access Terraform Changes

### 4.1 Updated: `terraform/tenant-access/locals.tf`

```terraform
# Load platform runtime configuration (generated by platform terraform)
locals {
  platform_runtime = yamldecode(file("${path.module}/../platform/platform-runtime.yaml"))
  
  # Extract platform data
  platform = {
    resource_group_name = local.platform_runtime.platform.resource_group_name
    resource_group_id   = local.platform_runtime.platform.resource_group_id
    apim_id             = local.platform_runtime.apim.id
    apim_name           = local.platform_runtime.apim.name
    apim_gateway_url    = local.platform_runtime.apim.gateway_url
    openai_api_name     = local.platform_runtime.apim.openai_api_name
  }
  
  # KAITO configuration
  kaito_gateway_ip = local.platform_runtime.kaito.gateway_ip
  kaito_models     = local.platform_runtime.kaito.models
  
  # Parse team configs (updated schema)
  teams = {
    for team_name, config in local.team_configs :
    team_name => {
      name         = config.team.name
      display_name = try(config.team.displayName, "AI Access - Team ${config.team.name}")
      owner        = config.team.owner
      cost_center  = try(config.team.costCenter, "")
      
      # Foundry models - simplified, no enabled flag
      foundry_models = [
        for model in try(config.models.foundry, []) : {
          name              = model.name
          tokens_per_minute = try(model.tokensPerMinute, 5000)
          daily_token_quota = try(model.dailyTokenQuota, 100000)
        }
      ]
      
      # KAITO models - references to shared instances
      kaito_models = [
        for model in try(config.models.kaito, []) : {
          name              = model.name
          tokens_per_minute = try(model.tokensPerMinute, 10000)
          daily_token_quota = try(model.dailyTokenQuota, 500000)
        }
      ]
    }
  }
  
  # Validate KAITO model requests against platform runtime
  kaito_validation_errors = flatten([
    for team_name, team in local.teams : [
      for model in team.kaito_models : 
        "Team '${team_name}' requested KAITO model '${model.name}' which is not enabled in platform"
      if !try(local.kaito_models[model.name].enabled, false)
    ]
  ])
}

# Validation check - fail if invalid models requested
resource "terraform_data" "validate_kaito_models" {
  count = length(local.kaito_validation_errors) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = false
      error_message = join("\n", local.kaito_validation_errors)
    }
  }
}
```

### 4.2 New File: `terraform/tenant-access/kaito_apim.tf`

```terraform
# APIM Backend pointing to Gateway API (single entry point for all KAITO models)
resource "azapi_resource" "apim_kaito_backend" {
  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name      = "kaito-gateway"
  parent_id = local.platform.apim_id

  body = {
    properties = {
      title       = "KAITO Gateway"
      description = "Internal Gateway API for platform-managed OSS models"
      protocol    = "http"
      url         = "http://${local.kaito_gateway_ip}"
    }
  }
}

# APIM API for KAITO models (OpenAI-compatible)
resource "azapi_resource" "apim_kaito_api" {
  type      = "Microsoft.ApiManagement/service/apis@2024-06-01-preview"
  name      = "kaito-openai"
  parent_id = local.platform.apim_id

  body = {
    properties = {
      displayName = "KAITO OpenAI Compatible API"
      description = "OpenAI-compatible API for platform-managed OSS models"
      path        = "kaito"
      protocols   = ["https"]
      serviceUrl  = "http://${local.kaito_gateway_ip}"
      subscriptionRequired = true
      subscriptionKeyParameterNames = {
        header = "api-key"
        query  = "api-key"
      }
    }
  }
}

# Operations for chat completions per model
resource "azapi_resource" "apim_kaito_operation" {
  for_each = local.kaito_models

  type      = "Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview"
  name      = "${each.key}-chat-completions"
  parent_id = azapi_resource.apim_kaito_api.id

  body = {
    properties = {
      displayName = "${each.value.display_name} - Chat Completions"
      method      = "POST"
      urlTemplate = "/deployments/${each.key}/chat/completions"
      request = {
        headers = []
        queryParameters = []
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

# Policy to route to KAITO backend via Gateway API path
resource "azapi_resource" "apim_kaito_operation_policy" {
  for_each = local.kaito_models

  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview"
  name      = "policy"
  parent_id = azapi_resource.apim_kaito_operation[each.key].id

  body = {
    properties = {
      format = "xml"
      value  = <<-XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="kaito-gateway" />
    <!-- Route to model-specific path on Gateway API -->
    <rewrite-uri template="${each.value.endpoint_path}/v1/chat/completions" />
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
    if length(team.kaito_models) > 0
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
```

### 4.3 Updated: `terraform/tenant-access/apim.tf` (policy additions)

Add KAITO models to the per-team policy XML generation:

```terraform
# Updated policy generation to include both Foundry AND KAITO models
locals {
  team_policies = {
    for team_name, team in local.teams : team_name => {
      policy_xml = <<-XML
<policies>
  <inbound>
    <base />
    <set-variable name="model-name" value="@(context.Request.MatchedParameters.GetValueOrDefault(&quot;deployment-id&quot;, &quot;&quot;))" />
    <choose>
${join("\n", [
  # Foundry models
  for model in team.foundry_models : <<-CONDITION
      <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;model-name&quot;) == &quot;${model.name}&quot;)">
        <llm-token-limit
          counter-key="@(context.Subscription.Id + &quot;-${model.name}&quot;)"
          tokens-per-minute="${model.tokens_per_minute}"
          token-quota="${model.daily_token_quota}"
          token-quota-period="Daily"
          estimate-prompt-tokens="true"
          remaining-tokens-header-name="x-ratelimit-remaining-tokens" />
      </when>
CONDITION
])}
${join("\n", [
  # KAITO models
  for model in team.kaito_models : <<-CONDITION
      <when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;model-name&quot;) == &quot;${model.name}&quot;)">
        <llm-token-limit
          counter-key="@(context.Subscription.Id + &quot;-kaito-${model.name}&quot;)"
          tokens-per-minute="${model.tokens_per_minute}"
          token-quota="${model.daily_token_quota}"
          token-quota-period="Daily"
          estimate-prompt-tokens="true"
          remaining-tokens-header-name="x-ratelimit-remaining-tokens" />
      </when>
CONDITION
])}
      <otherwise>
        <return-response>
          <set-status code="403" reason="Model not authorized" />
          <set-body>{"error":{"code":"ModelNotAuthorized","message":"Model not in allowed list"}}</set-body>
        </return-response>
      </otherwise>
    </choose>
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
      XML
    }
  }
}
```

---

## Phase 5: Remove Per-Team KAITO Deployment

### Delete: `terraform/tenant-access/kubernetes.tf`

The current file deploys per-team KAITO workspaces. This should be removed entirely as KAITO is now managed by platform terraform.

### Delete: `charts/developer-access/`

The Helm chart for per-team KAITO deployment is no longer needed:
- `charts/developer-access/Chart.yaml`
- `charts/developer-access/values.yaml`
- `charts/developer-access/templates/kaito-workspace.yaml`
- `charts/developer-access/templates/_helpers.tpl`

This chart was used for GitOps-style per-team KAITO deployment. With the new shared model approach, KAITO workspaces are managed centrally by platform terraform.

---

## Phase 6: Update Models Chart

### Update: `charts/models/`

This chart can remain for reference/documentation of available model presets, but actual deployment is now via platform terraform's `model_catalog.yaml`.

Consider renaming to `charts/models-reference/` or adding a README explaining its purpose.

---

## Implementation Order

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 1: Create model_catalog.yaml in platform terraform                     │
│         - Define all supported KAITO models                                  │
│         - Mark initial models as enabled: true                               │
└─────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 2: Add KAITO + Gateway API deployment to platform terraform            │
│         - kaito.tf with kubernetes_manifest for workspaces                  │
│         - gateway.tf with Gateway + HTTPRoutes per model                    │
│         - Wait for Gateway IP assignment                                     │
│         - Generate platform-runtime.yaml with all runtime info              │
└─────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 3: Ensure APIM Standard v2 has VNET integration                         │
│         - Verify APIM is injected into VNET                                  │
│         - Confirm it can reach internal Gateway IP                          │
└─────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 4: Run platform terraform apply                                         │
│         - Deploys shared KAITO workspaces                                    │
│         - Deploys Gateway API with internal LoadBalancer                    │
│         - Creates HTTPRoutes for each model                                  │
│         - Waits for GPU provisioning (~10-20 min)                            │
│         - Generates platform-runtime.yaml                                    │
└─────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 5: Update tenant-access terraform                                       │
│         - Read platform-runtime.yaml for KAITO info                         │
│         - Add APIM backend pointing to Gateway IP                            │
│         - Add APIM API and operations for KAITO                              │
│         - Update policy generation for KAITO models                          │
│         - Add validation for catalog membership                              │
│         - Remove old kubernetes.tf                                           │
└─────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 6: Update team access.yaml schema                                       │
│         - Remove enabled flags                                               │
│         - Change kaito.workspaces to kaito (list of model refs)             │
│         - Add tokensPerMinute and dailyTokenQuota                            │
└─────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 7: Cleanup                                                              │
│         - Delete charts/developer-access/                                    │
│         - Update docs/GITOPS_DESIGN.md with new architecture                │
│         - Commit platform-runtime.yaml to repo                               │
└─────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Step 8: Run tenant-access terraform apply                                    │
│         - Validates team requests against platform-runtime.yaml             │
│         - Creates APIM configuration                                         │
│         - Teams can now call KAITO models via APIM                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Networking Architecture (Decision: Gateway API)

### Chosen Approach: Gateway API with VNET Integration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure VNET                                     │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  APIM Subnet (APIM Standard v2 - VNET Injected)                        │ │
│  │    ├── apim-ai-platform.azure-api.net                                  │ │
│  │    └── Can reach any IP within VNET                                    │ │
│  └──────────────────────────────────┬─────────────────────────────────────┘ │
│                                     │                                       │
│  ┌──────────────────────────────────▼─────────────────────────────────────┐ │
│  │  AKS Subnet                                                            │ │
│  │    ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │    │  Gateway API (Kubernetes Gateway Controller)                    │ │ │
│  │    │    ├── Gateway resource with internal LoadBalancer IP           │ │ │
│  │    │    └── HTTPRoute per KAITO model                                │ │ │
│  │    │         ├── /phi-4/* → workspace-phi-4:80                       │ │ │
│  │    │         └── /mistral-7b/* → workspace-mistral-7b:80             │ │ │
│  │    └─────────────────────────────────────────────────────────────────┘ │ │
│  │    ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │    │  KAITO Workspaces (ClusterIP Services)                          │ │ │
│  │    │    ├── workspace-phi-4:80                                       │ │ │
│  │    │    └── workspace-mistral-7b:80                                  │ │ │
│  │    └─────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Components:

1. **APIM Standard v2**: Injected into VNET subnet, can reach internal IPs
2. **Gateway API**: Kubernetes-native ingress with internal LoadBalancer IP
3. **HTTPRoutes**: Path-based routing to KAITO services
4. **Single Entry Point**: One Gateway IP for all KAITO models

### Gateway API Resources

```yaml
# GatewayClass (usually pre-installed with AKS)
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: azure-alb-internal
spec:
  controllerName: alb.networking.azure.io/alb-controller

---
# Gateway with internal LoadBalancer
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kaito-gateway
  namespace: default
  annotations:
    alb.networking.azure.io/alb-frontend-type: "internal"
spec:
  gatewayClassName: azure-alb-internal
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Same

---
# HTTPRoute per model
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kaito-phi-4
  namespace: default
spec:
  parentRefs:
    - name: kaito-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /phi-4
      backendRefs:
        - name: workspace-phi-4
          port: 80
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /v1
```

### APIM Backend Configuration

```terraform
# Single backend pointing to Gateway IP
resource "azapi_resource" "apim_kaito_backend" {
  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name      = "kaito-gateway"
  parent_id = local.platform.apim_id

  body = {
    properties = {
      title       = "KAITO Gateway"
      description = "Internal Gateway API for KAITO models"
      protocol    = "http"
      url         = "http://${local.kaito_gateway_ip}"  # From platform-runtime.yaml
    }
  }
}
```

---

## Validation Rules

| Rule | Error Message |
|------|---------------|
| KAITO model not in catalog | "Model 'xxx' is not defined in platform model catalog" |
| KAITO model not enabled | "Model 'xxx' exists but is not enabled. Contact platform team" |
| Duplicate model in team config | "Model 'xxx' is defined multiple times in team config" |
| Invalid tokens/quota values | "tokensPerMinute must be > 0 and <= model capacity" |

---

## Future Enhancements (Out of Scope)

1. **Billing Integration**: Export APIM metrics to Cost Management for showback
2. **Auto-scaling**: Scale KAITO replicas based on aggregate team quotas
3. **Model Versioning**: Support multiple versions of same model
4. **Priority Queuing**: Prioritize requests based on team tier
5. **Burst Handling**: Allow controlled bursting above quota at premium rate
