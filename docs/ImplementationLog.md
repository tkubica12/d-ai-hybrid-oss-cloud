# Implementation Log

## Networking Module (Date: 2025-09-22)

Implemented Terraform networking module providing:
- Virtual Network with configurable CIDR (default /16).
- Programmatic creation of ordered subnets (/24 each via `cidrsubnet`) for: aks, aks-api, onprem, private-endpoint, AzureBastionSubnet, jump, api-management.
- NAT Gateway (Standard) with static public IP associated to all subnets except AzureBastionSubnet.
- Network Security Group per subnet (excluding AzureBastionSubnet) with no default rules beyond Azure defaults (placeholder for future rules).
- Optional Basic Azure Bastion (enabled by default) using dedicated AzureBastionSubnet and its own Standard public IP.
- Private DNS Zones for ACR (`privatelink.azurecr.io`) and Blob storage (`privatelink.blob.core.windows.net`) plus VNet links.
- Outputs for VNet ID, all subnet IDs, NAT gateway, Bastion, and DNS zone IDs.

Design decisions:
- Random suffix generated in root and passed into module to keep a single randomness source and enable deterministic plan changes if only module code updates.
- Bastion not behind NAT gateway and without NSG association to follow Azure best practices.
- Subnet address allocation uses `cidrsubnet(var.vnet_cidr, 8, index)` producing /24 networks from /16. Changing base CIDR or list order will force subnet recreation.
- NSG rules intentionally omitted at this stage to keep demo minimal; can be extended later via additional variables/maps.

Potential future enhancements:
- Allow custom subnet CIDR sizes via a map.
- Add optional delegation (e.g., for AKS or APIM) via configuration structure.
- Extend Private DNS zones list to include e.g., `privatelink.queue.core.windows.net`, `privatelink.file.core.windows.net` if needed.

## Refactor (Date: 2025-09-22)

Refactored networking module per updated requirements:
- Removed variables: prefix, random_suffix, subnet_names, private_dns_zones, create_bastion, bastion_sku, nat_gateway_sku.
- Introduced inputs: base_name, base_name_nodash to leverage root locals for consistent naming.
- Converted subnet list, private DNS zones, Bastion/NAT SKU, and naming patterns into `locals.tf` for clearer separation of concerns.
- Split monolithic `main.tf` into: `locals.tf`, `networking.tf` (VNet, subnets, NAT, NSGs, Bastion), `dns.tf` (Private DNS resources).
- Bastion is now always created (Basic SKU) simplifying conditional logic and outputs.
- Simplified outputs (`bastion_id` no longer wrapped in `try`).
- Updated root module invocation to pass new variables and removed obsolete ones.

Rationale:
- Reduces surface of configurable inputs to essentials, avoiding premature abstraction.
- Ensures naming uniformity by centralizing randomness in root local values.
- File separation improves readability and future extensibility (e.g., adding private endpoints later).

Next considerations:
- If customization of subnets or DNS zones becomes necessary, reintroduce as structured maps (avoiding positional indexes problems).
- Add NSG rule sets via variable-driven dynamic blocks.

## Monitoring Module (Date: 2025-09-22)
Added `monitoring` module creating Log Analytics Workspace, Azure Monitor Workspace (Prometheus), and Managed Grafana (Standard). Outputs expose IDs for integration with AKS.

## AKS Kaito Module (Date: 2025-09-22)
Added `aks-kaito` module provisioning AKS cluster with user-assigned identity, node pool in `aks` subnet and secondary pool in `aks-api` subnet, Log Analytics integration, and placeholder Kaito extension via `azapi_resource` for managed cluster extension. Role assignments grant Monitoring Data Reader and Log Analytics Contributor on respective workspaces to the UAI.

Notes:
- Schema for Kaito extension may evolve; adjust `type`/properties when official provider support is available.
- Network profile currently uses Azure CNI with load balancer outbound; may switch to UDR if custom egress is required later.
 - Attempted native `addon_profile { kaito {} }` block but current azurerm provider in use does not expose it (Terraform plan failed with unsupported block); retained azapi extension approach as interim.

## AKS NAP + azapi Migration (Date: 2025-09-22)
Refactored AKS provisioning to use `azapi_resource` for `Microsoft.ContainerService/managedClusters@2025-05-01` enabling:
- Node Auto Provisioning via `nodeProvisioningProfile.mode = Auto`.
- KAITO enablement through `aiToolchainOperatorProfile.enabled = true` (removing separate extension resource).
- `azureMonitorProfile.metrics` and legacy `omsagent` addon referencing Log Analytics workspace.
- Azure CNI overlay + Cilium dataplane/networkPolicy in network profile; API server VNet integration using delegated `aks-api` subnet.

Changes:
- Removed native `azurerm_kubernetes_cluster` + node pool resources; replaced with single ARM body.
- Added subnet delegation for `aks-api` to `Microsoft.ContainerService/managedClusters`.
- Simplified outputs; kubelet identity currently not exposed (set to null placeholder).

Considerations / Next Steps:
- Replace placeholder SSH public key with real key prior to deployment.
- If azurerm provider adds first-class NAP + KAITO support, plan migration path (state import or replacement) to return to native resources.
- Potentially surface configurable fields (autoUpgradeProfile, maintenance configs) later.

## AKS Permission Fix (Date: 2025-09-22)
Issue: Initial `azapi_resource` AKS creation failed with `ResourceMissingPermissionError` complaining about missing permission `Microsoft.Network/virtualNetworks/subnets/joinLoadBalancer/action` on the target subnets (notably API server integration subnet).

Resolution:
- Added data lookup for `Network Contributor` role.
- Assigned Network Contributor at VNet scope to the AKS user-assigned identity before (re)creating the cluster.
- Re-applied Terraform; cluster provisioned successfully after ~7 minutes.

Rationale:
AKS control plane and load balancer operations require subnet-level join and LB actions that are covered by Network Contributor when using UAI for managed cluster identity. Granting at VNet scope simplifies future subnet additions (vs. per-subnet scoped roles) while remaining within least-privilege boundaries for networking tasks.

Follow-ups:
- Optionally narrow scope to only required subnets if principle of least privilege must be strictly minimized.
- Add documentation for required roles in module README if external consumption expected.

## Model Workspace Chart (Date: 2025-09-24)

Implemented Helm chart scaffold for Kaito workspace manifests:
- Created base `Chart.yml` with metadata (`apiVersion`, `name`, semantic `version`, and `appVersion`).
- Added `templates/gpt-oss-20b.yaml` workspace manifest targeting `Standard_NV36ads_A10_v5` per requirements.

Design notes:
- Kept chart type `application` to align with standard Helm packaging and ease future extension with values-driven templating.
- Left manifest values static for now; will parameterize via `values.yaml` when additional workspaces are introduced.

## AKS Module Restructure (Date: 2025-09-25)

Refined `aks-kaito` Terraform module layout for clarity:
- Retained locals and subscription/client data sources in `main.tf`.
- Moved AKS managed cluster, SSH key, and user-assigned identity resources into new `kas.tf`.
- Extracted role assignments to dedicated `rbac.tf` for easier permission management visibility.
- Collected output declarations in `outputs.tf` keeping exported values discoverable.

Rationale:
- Aligns with repository convention of splitting files by resource category per Terraform guidance.
- Simplifies navigation when adjusting RBAC scopes, outputs, or cluster configuration individually.

Next steps:
- Consider documenting module usage specifics in a README under `terraform/modules/aks-kaito` if reused externally.

## ArgoCD Extension (Date: 2025-09-25)

Enabled GitOps support through the Microsoft ArgoCD extension:
- Added locals for extension naming, namespace, and default application visibility.
- Introduced configurable variables for version, release train, auto-upgrade, and HA toggle with sensible defaults.
- Created `extensions.tf` provisioning a cluster-scoped extension via `azapi_resource` with configuration mirroring Microsoft Learn guidance (cluster-wide install, HA optional).

Rationale:
- Provides managed ArgoCD deployment aligned with Azure preview recommendations without relying on CLI automation.
- Allows consumers to opt into new builds or HA through module inputs while keeping defaults ready for demo environments.

Next steps:
- Evaluate adding workload identity parameters once identities are in place for production usage.

## ArgoCD Bootstrap Automation (Date: 2025-09-25)

Automated GitOps bootstrap after extension installation:
- Added `argocd/bootstrap-application.yaml` defining a cluster-wide app-of-apps pointing to `argocd/apps` for future workloads.
- Scoped a companion README in both `argocd/` and `argocd/apps/` to explain manifest layout.
- Introduced `argocd_bootstrap_manifest_url` variable with default raw GitHub URL and wired `azapi_resource_action` `runCommand` call in `bootstrap.tf` to execute `kubectl apply` via AKS Run Command once the extension is ready.

Rationale:
- Keeps bootstrap logic entirely within Azure APIs, enabling full automation without separate scripts.
- Makes it easy to extend GitOps footprint by committing additional Argo CD Applications under `argocd/apps`.

Next steps:
- Consider toggling bootstrap based on environment (e.g., different branches) or templating multiple bootstrap manifests when needed.

## Envoy Gateway GitOps (Date: 2025-09-25)

Bootstrapped Envoy Gateway deployment through Argo CD:
- Added `argocd/apps/envoy-gateway.yaml` Application installing the upstream OCI Helm chart (`gateway-helm` v1.5.1) into `envoy-gateway-system` with namespace auto-creation.
- Enabled automated sync, prune, and self-heal so Helm upgrades propagate without manual intervention.

Next steps:
- Commit additional Gateway/HTTPRoute resources under `argocd/apps` to publish workloads once Envoy Gateway is running.

## Azure Service Operator Workload Identity (Date: 2025-09-27)

Enabled Azure Service Operator v2 with managed identity authentication tied to the AKS workload identity issuer:
- Added a dedicated user-assigned managed identity for ASO, federated identity credential, and Contributor role assignment at subscription scope.
- Enabled `securityProfile.workloadIdentity` and the OIDC issuer on the AKS cluster ARM template, exporting issuer URL via module outputs.
- Extended the AKS bootstrap Run Command to apply a `platform-bootstrap-settings` ConfigMap carrying non-sensitive Helm values (subscription, tenant, managed identity client ID, CRD pattern, chart metadata).
- Introduced an Argo CD application that installs the upstream ASO Helm chart using `valuesFrom` to consume the Terraform-generated ConfigMap, plus README updates documenting the new workload.

## ASO Workload Identity Fix (Date: 2025-09-27)

Resolved Terraform apply failure for the ASO federated identity credential:
- Restored `response_export_values` on the AKS `azapi_resource` so the workload identity issuer URL is persisted in state.
- Simplified issuer extraction by reading the structured `output` map instead of attempting to `jsondecode` the response payload.
- Successfully re-ran `terraform plan` and `terraform apply -auto-approve`, creating the ASO workload identity and updating the cluster in place.

## AI Foundry Helm Chart (Date: 2025-09-27)

Added a standalone Helm chart for provisioning an AI Foundry account via Azure Service Operator:
- Created `charts/foundry` with chart metadata and default values for resource group and account naming.
- Authored a single template emitting the Azure Resource Group and Cognitive Services `Account` resources, wired to values for location, SKU, and access settings.
- Configured system-assigned identity, workload ownership, and AI Foundry-specific properties (public network access, project management) to align with ASO schema expectations.

## NAT Association Stabilization (Date: 2025-09-27)

Mitigated intermittent `AnotherOperationInProgress` errors when applying Terraform networking module:
- Added explicit dependency from `azurerm_subnet_nat_gateway_association` resources to the NSG associations to serialize subnet mutations.
- Ensures Terraform waits for security group attachments to complete before wiring the NAT gateway, reducing Azure control plane conflicts during apply.

## cert-manager GitOps (Date: 2025-09-28)

Addressed Azure Service Operator dependency failures in Argo CD by managing cert-manager via GitOps:
- Added `argocd/apps/cert-manager.yaml` deploying the upstream Jetstack Helm chart with CRDs enabled and namespace auto-creation.
- Documented the new application alongside existing workloads to keep bootstrap guidance current.

## ASO CRD Scope (Date: 2025-09-28)

Prevented Azure Service Operator from attempting to install all 250+ CRDs by tightening the default pattern:
- Limited `aso_crd_pattern` Terraform variable to the Cognitiveservices and API Management groups plus common dependencies (resource, managed identity, Key Vault).
- Ensures Argo CD chart sync succeeds with only the CRDs required for planned workloads.

## ASO Helm Values Fix (Date: 2025-09-28)

Resolved Azure Service Operator deployment failing to read Terraform-provided settings:
- Corrected the Argo CD Application to reference the ConfigMap data using `valuesKey`, enabling Helm to consume the generated `aso-values.yaml` (including CRD pattern and Azure identity fields).

## Envoy Gateway Chart Vendor (Date: 2025-09-28)

Eliminated Argo CD Helm fetch failures for Envoy Gateway by vendoring the chart:
- Pulled `gateway-helm` v1.5.1 from the OCI registry and committed the unpacked chart under `charts/gateway-helm` for Git-based delivery.
- Repointed the Argo CD Application to the in-repo chart path so the repo-server no longer issues unsupported OCI pull commands.
- Kept the lightweight inline values to configure the Kubernetes provider without diverging from upstream defaults.

## Envoy Gateway OCI Source (Date: 2025-09-29)

Returned Envoy Gateway to the upstream distribution without keeping a vendored chart in-repo:
- Removed the vendored `charts/gateway-helm` directory in favor of referencing the upstream `envoyproxy/gateway` Git repository (chart path `charts/gateway-helm`) pinned to tag `v1.5.1`.
- Updated the Argo CD application to a multi-source definition that combines the upstream Git-hosted chart with Git-tracked overrides in `argocd/values/envoy-gateway.yaml`.
- Added a dedicated values file under `argocd/values/` to keep configuration alongside the manifest while remaining consistent with the new GitOps pattern.

## ASO CRD Pattern Patch (Date: 2025-09-28)

Unblocked the Azure Service Operator controller crash loop caused by an empty `--crd-pattern` argument:
- Replaced the unsupported `helm.valuesFrom` block in the Argo CD Application with an explicit Helm parameter that sets the semicolon-delimited CRD pattern while forcing string semantics.
- Left the Terraform-managed ConfigMap in place for future consolidation, noting a follow-up to reconcile the two sources of truth.

## ASO Helm Inline Values (Date: 2025-09-28)

Stabilized the Azure Service Operator GitOps deployment after removing `valuesFrom` support:
- Inlined the subscription, tenant, client ID, workload identity flag, CRD pattern, and service-account annotations directly in the Argo CD `helm.valuesObject` so Helm renders the chart with the required configuration.
- Confirmed values match those generated in the bootstrap ConfigMap to keep workload identity credentials and CRD scope aligned until a dynamic hand-off is reintroduced.

## ASO Helm Env Bridge (Date: 2025-09-28)

Replaced the temporary inline Helm configuration with Terraform-driven environment variables to keep Git clean of sensitive IDs:
- Switched the Argo CD Application for ASO to consume `$ARGOCD_ENV_*` placeholders so Helm resolves values supplied by the repo-server environment.
- Extended the Terraform bootstrap module to export the ASO identity and config entries as environment variables via the `platform-bootstrap-settings` ConfigMap and repo-server `envFrom` patch.
- Preserved the existing ConfigMap payload while ensuring terraform remains the single source of truth for workload identity parameters and CRD scope.

## ASO GitOps Values Realignment (Date: 2025-09-29)

Adopted a pure GitOps flow for Azure Service Operator runtime settings now that no secrets are required:
- Removed the Terraform-managed ConfigMap and repo-server environment patch, simplifying the AKS bootstrap Run Command to only apply the Argo CD app-of-apps manifest.
- Added a Terraform-managed `local_file` artifact that renders the ASO Helm values into `argocd/values/azure-service-operator.yaml` for manual commit and promotion through Git.
- Converted the Argo CD application to a multi-source definition that pulls the remote Helm chart while loading the Git-stored values file, keeping configuration close to the manifests without runtime bridging.

## Envoy Gateway OCI Registry Fix (Date: 2026-01-23)

Resolved Envoy Gateway Helm chart deployment failures in ArgoCD:
- Multi-source Git reference with values file caused nil pointer errors due to Helm values structure mismatch with chart expectations.
- Migrated to single-source OCI-based deployment using `registry-1.docker.io/envoyproxy` as repoURL with `gateway-helm` as chart name.
- Removed external values file dependency since default chart values are sufficient for basic deployment.
- ArgoCD now successfully deploys Envoy Gateway controller with all Gateway API CRDs registered.

Technical notes:
- ArgoCD OCI chart format requires `repoURL: registry-1.docker.io/<org>` with `chart: <chartname>` (not the full OCI URL).
- The `cert-manager` and `envoy-gateway` apps show `OutOfSync` due to webhook configurations being dynamically modified by their controllers - this is expected and harmless since health status is `Healthy`.
- GatewayClass resource must be created separately to enable Gateway provisioning with Envoy Gateway controller.

## AI Gateway GitOps Implementation (Date: 2026-01-23)

Implemented GitOps-based AI Gateway infrastructure using Azure Service Operator v2:

### Architecture Design
- Created comprehensive design document at `docs/GITOPS_DESIGN.md` outlining developer self-service model access architecture.
- Central model management: Foundry hosts centralized model deployments (gpt-4.1, gpt-5.2) accessible by multiple teams.
- APIM as AI Gateway: Provides token rate limiting via `llm-token-limit` and quota management via `quota-by-key` policies.
- Per-team isolation: APIM Products + Subscriptions provide isolated API keys and quota limits per team.

### Charts Created
1. **charts/ai-gateway/** - APIM infrastructure chart:
   - `templates/service.yaml` - APIM Service using v1api20220801 with Developer SKU
   - `templates/backend-foundry.yaml` - Backend pointing to Foundry endpoint
   - `templates/api-foundry.yaml` - OpenAI-compatible API definition

2. **charts/foundry/** - Enhanced to support AIServices account creation via ASO

### ArgoCD Applications
- `argocd/apps/ai-gateway.yaml` - Deploys APIM infrastructure with subscription ID parameter
- `argocd/apps/foundry-account.yaml` - Deploys Foundry AIServices account

### Technical Fixes Applied
1. **API Version Mismatch**: Changed APIM resources from v1api20240501 to v1api20220801 (installed ASO version)
2. **SKU Validation**: Changed from "BasicV2" (unsupported in older API) to "Developer"
3. **Owner Reference**: Changed from `owner.name` to `owner.armId` for cross-namespace ResourceGroup reference
4. **APIM Name Conflict**: Added unique suffix to avoid global naming collision

### Status
- ✅ Foundry Account (af-foundry-ai) - Successfully provisioned
- 🔄 APIM Service (apim-ai-hai-twej) - Provisioning (~30-40 min)
- ✅ Developer Access chart - Created and tested
- ✅ ApplicationSet - Created and generating applications

### Current Deployment State
- `access-team-alpha` ArgoCD Application - Created by ApplicationSet
- Resources created in `developer-requests` namespace:
  - Product: product-alpha (waiting for APIM)
  - ProductPolicy: product-alpha-policy (waiting for Product)
  - Subscription: subscription-alpha (waiting for APIM)

### Next Steps
- Wait for APIM to finish provisioning (~30-40 min)
- All dependent resources (Product, ProductPolicy, Subscription) will reconcile automatically
- API keys will be exported to `alpha-api-key` Kubernetes Secret
- Add KAITO backend integration to APIM

## AI Platform Terraform Module (Date: 2026-01-23)

Restructured AI Gateway architecture to use Terraform for shared infrastructure while keeping GitOps for per-team resources:

### Architecture Change
Based on user feedback, moved shared components from GitOps (ASO) to Terraform:
- **Terraform-managed (shared)**: APIM v2 Standard, Foundry AIServices, API definitions, Backends, Role Assignments
- **GitOps-managed (per-team)**: Foundry Projects, APIM Products, ProductPolicies, Subscriptions, KAITO Workspaces

### Why This Change
- APIM v2 Standard tier provisions in ~1m20s (vs 30-40 min for Developer tier)
- Shared infrastructure benefits from Terraform's plan/apply workflow and state management
- Per-team resources suit self-service GitOps model via ApplicationSet

### New Terraform Module: `terraform/modules/ai-platform/`
Created comprehensive module with the following resources:

| File | Resources |
|------|-----------|
| `main.tf` | Locals, random suffix, APIM lookup |
| `foundry.tf` | AIServices account with SystemAssigned identity |
| `apim.tf` | APIM v2 StandardV2, Backend, API, 3 Operations, Policy |
| `rbac.tf` | APIM → Foundry role assignment (Cognitive Services OpenAI User) |
| `variables.tf` | Module inputs |
| `outputs.tf` | apim_name, apim_gateway_url, foundry_name, foundry_endpoint, openai_api_name |

### Resources Deployed
```
apim-hai-twej         - APIM v2 StandardV2 (1m20s)
af-hai-twej           - Azure AI Foundry AIServices (26s)
foundry-backend       - APIM Backend → Foundry endpoint
openai-api            - OpenAI-compatible API definition
chat-completions      - POST /deployments/{deployment-id}/chat/completions
completions           - POST /deployments/{deployment-id}/completions
embeddings            - POST /deployments/{deployment-id}/embeddings
policy                - API policy with managed identity auth
Role Assignment       - APIM identity → Cognitive Services OpenAI User
```

### Outputs
- `apim_gateway_url = "https://apim-hai-twej.azure-api.net"`
- `foundry_endpoint = "https://af-hai-twej.cognitiveservices.azure.com/"`

### GitOps Updates
- Removed `argocd/apps/ai-gateway.yaml` and `argocd/apps/foundry-account.yaml`
- Removed `charts/ai-gateway/` and `charts/foundry/` directories
- Updated `charts/developer-access/` to reference Terraform-managed resources via parameters
- Added `foundry-project.yaml` template for per-team project creation

### Bug Fixes
- **statisticsEnabled error**: AIServices kind doesn't support `apiProperties.statisticsEnabled` - removed the block from foundry.tf
- **OpenAI API name mismatch**: ProductApi referenced `foundry-openai-api` but Terraform creates `openai-api` - made configurable via values
- **ProductPolicy llm-token-limit**: APIM policy validation failed with llm-token-limit - simplified to use standard `rate-limit-by-key` and `quota-by-key` policies

### Key Learnings
1. APIM v2 Standard provisions dramatically faster than Developer tier
2. azapi provider with ARM API versions enables latest features (v2 SKU, AIServices)
3. Hybrid Terraform+GitOps works well: Terraform for platform, GitOps for tenants
4. ASO doesn't allow updating `owner.armId` - resources must be deleted and recreated when owners change
5. ArgoCD may cache old revisions - use `argocd.argoproj.io/refresh=hard` annotation to force refresh

### Final State
All per-team resources successfully deployed via GitOps:
- ✅ Product: `product-alpha` - APIM product with approval required
- ✅ Subscription: `subscription-alpha` - API key exported to `alpha-api-key` secret
- ✅ ProductApi: `product-alpha-foundry-api` - Links product to OpenAI API
- ✅ ProductPolicy: `product-alpha-policy` - Token-based rate limiting (5K tokens/min, 100K daily quota)

## APIM Policy Improvement & Foundry Project Limitation (Date: 2026-01-24)

### Token-Based Rate Limiting
Replaced call-based rate limiting with token-based limiting using the `llm-token-limit` APIM policy:
- Changed from `rate-limit-by-key` + `quota-by-key` (call-based) to `llm-token-limit` (token-based)
- Removed `renewalPeriod` parameter since daily quota implies `Daily` period
- Updated limits to use `tokensPerMinute` and `dailyTokenQuota`
- Added response headers: `x-ratelimit-remaining-tokens`, `x-quota-remaining-tokens`, `x-tokens-consumed`

Benefits:
- LLM APIs consumption measured in tokens, not calls - more accurate billing/quota enforcement
- Built-in prompt token estimation (`estimate-prompt-tokens="true"`)
- Daily quota resets automatically at UTC day boundary

### Foundry Project Limitation
Discovered that Azure Service Operator (ASO) does not support the `Microsoft.CognitiveServices/accounts/projects` resource type:
- ASO only has `Account` and `Deployment` for CognitiveServices (v1api20250601)
- Attempting to create an Account with owner pointing to another Account fails with validation error
- Commented out the foundry-project.yaml template until ASO adds support
- Documented workaround: create projects manually via Azure CLI

Workaround for teams needing Playground access:
```bash
az cognitiveservices account project create \
  --name <foundry-resource-name> \
  --resource-group <resource-group> \
  --project-name project-<team-name> \
  --location <location>
```

Track ASO support at: https://github.com/Azure/azure-service-operator/issues

## Full Terraform Migration - ArgoCD/ASO to Pure Terraform (Date: 2026-01-24)

### Architecture Change
Migrated from hybrid ArgoCD/ASO approach to pure Terraform-based tenant provisioning:
- **Old approach**: ArgoCD ApplicationSet + Azure Service Operator for per-team resources
- **New approach**: Terraform tenant-access state reads YAML files and provisions all resources

### New Terraform Structure
Split Terraform into two separate states for separation of concerns:

```
terraform/
├── platform/           # Core infrastructure (run by platform team)
│   ├── main.tf        # Module orchestration
│   ├── providers.tf   # azapi, azurerm providers
│   ├── variables.tf   # prefix, location, subscription_id
│   ├── locals.tf      # Naming conventions
│   ├── outputs.tf     # Exports for tenant-access
│   └── modules/       # Copied from original terraform/modules
│
└── tenant-access/      # Per-team resources (run separately)
    ├── providers.tf   # Azure + Kubernetes + Helm providers
    ├── variables.tf   # platform_state_path, developer_requests_path
    ├── data.tf        # Remote state + AKS data source
    ├── locals.tf      # Parse developer-requests YAML files
    ├── apim.tf        # Products, policies, subscriptions
    ├── apim_keys.tf   # Data source for subscription secrets
    ├── foundry.tf     # Foundry projects per team
    ├── kubernetes.tf  # Namespaces and secrets
    └── outputs.tf     # Team info and API keys
```

### Developer Requests Format
Kept the same YAML-based self-service model:
```yaml
# developer-requests/team-alpha/access.yaml
apiVersion: ai.contoso.com/v1
kind: TeamAccessRequest
metadata:
  name: team-alpha
spec:
  owner: alpha-lead@contoso.com
  costCenter: CC-12345
  models:
    - type: azure-openai
      limits:
        tokensPerMinute: 50000
        dailyTokenQuota: 1000000
```

### Resources Created Per Team
| Resource Type | Resource Name | Description |
|--------------|---------------|-------------|
| APIM Product | `product-{team}` | Published product with approval required |
| APIM Policy | Token-based limits | `llm-token-limit` policy |
| APIM API Link | `link-openai-api` | Links product to OpenAI API |
| APIM Subscription | `sub-{team}` | Auto-approved subscription |
| Foundry Project | `project-{team}` | Team workspace in Azure AI Foundry |
| K8s Namespace | `team-{name}` | With owner/cost-center annotations |
| K8s Secret | `ai-gateway-credentials` | APIM gateway URL and API key |

### Key Technical Decisions

1. **State Bridging**: `terraform_remote_state` connects tenant-access to platform outputs
2. **azapi for APIM**: Using API version `2024-06-01-preview` for `llm-token-limit` policy support
3. **azapi for Foundry Projects**: CognitiveServices API version `2025-06-01` for project resources
4. **Kubernetes Auth**: Client certificate authentication from `azurerm_kubernetes_cluster.kube_config`

### Kubernetes Provider Authentication
Initially encountered "Unauthorized" errors with Kubernetes provider. Resolution:
- AKS created without AAD integration (`aadProfile: null`)
- `kube_config` provides client certificates when local accounts are enabled
- Provider configured with `host`, `cluster_ca_certificate`, `client_certificate`, `client_key`

### Migration Steps Performed
1. Created `terraform/platform/` directory structure
2. Copied modules from `terraform/modules/` to `terraform/platform/modules/`
3. Migrated state with `terraform state mv` commands
4. Created tenant-access module with all resource types
5. Imported existing APIM product created by ArgoCD
6. Deleted old ArgoCD-created subscriptions/policies via REST API
7. Successfully applied both platform and tenant-access states

### Verification
All resources successfully created and verified:
```bash
# APIM Product
az apim product show -g rg-hai-twej -n apim-hai-twej --product-id product-alpha
# → State: published, displayName: "AI Access - Team Alpha"

# Foundry Project
az rest --method GET --uri ".../projects?api-version=2025-06-01"
# → project-alpha exists in af-hai-twej

# K8s Namespace
kubectl get namespace team-alpha
# → Status: Active, labels include terraform-managed

# K8s Secret
kubectl get secret ai-gateway-credentials -n team-alpha
# → Contains APIM_GATEWAY_URL, APIM_API_KEY, OPENAI_API_BASE, OPENAI_API_KEY
```

### Next Steps
- Add GitHub Actions workflow for automated tenant-access apply on PR merge
- Configure Terraform state storage in Azure Storage Account
- Consider adding KAITO workspace provisioning per team model requests

## Post-Migration Cleanup - Remove ArgoCD/ASO (Date: 2026-01-24)

After migrating to pure Terraform, cleaned up obsolete ArgoCD and ASO components.

### Removed from AKS Module
| File/Resource | Description |
|---------------|-------------|
| `extensions.tf` | Deleted - contained ArgoCD AKS extension |
| `bootstrap.tf` | Deleted - contained run command for ArgoCD bootstrap and ASO values file generation |
| `azurerm_user_assigned_identity.aso` | Removed from aks.tf |
| `azurerm_role_assignment.aso_contributor` | Removed from rbac.tf |
| `azurerm_federated_identity_credential.aso` | Removed from aks.tf |
| ArgoCD variables | Removed `argocd_version`, `argocd_train`, `argocd_auto_upgrade`, `argocd_ha`, `argocd_bootstrap_manifest_url`, `aso_crd_pattern` |
| ASO outputs | Removed `aso_managed_identity_id`, `aso_managed_identity_client_id`, `aso_managed_identity_principal_id`, `aso_workload_identity_subject` |

### Removed from Repository
| Path | Description |
|------|-------------|
| `argocd/` | Entire folder deleted (bootstrap-application.yaml, apps/, values/) |
| `charts/developer-access/templates/product.yaml` | APIM Product resource (now in Terraform) |
| `charts/developer-access/templates/product-api.yaml` | APIM Product API link (now in Terraform) |
| `charts/developer-access/templates/product-policy.yaml` | APIM Product Policy (now in Terraform) |
| `charts/developer-access/templates/subscription.yaml` | APIM Subscription (now in Terraform) |
| `charts/developer-access/templates/foundry-project.yaml` | Foundry Project (now in Terraform) |

### Updated Developer-Access Helm Chart
The chart now only handles KAITO workspaces for teams that request open-source model hosting:
- Simplified `values.yaml` to only `team.name` and `kaito.workspaces`
- Simplified `_helpers.tpl` to remove APIM/Foundry ARM ID helpers
- Updated `kaito-workspace.yaml` to use new `kaito.enabled` path instead of `models.kaito.enabled`

### Azure Resources Destroyed
```bash
terraform apply  # 5 resources destroyed in ~17 minutes
- module.aks_kaito.azapi_resource.argocd_extension
- module.aks_kaito.azapi_resource_action.argocd_bootstrap[0]
- module.aks_kaito.azurerm_federated_identity_credential.aso
- module.aks_kaito.azurerm_role_assignment.aso_contributor
- module.aks_kaito.azurerm_user_assigned_identity.aso
```

### Current State Summary
| Component | Managed By |
|-----------|------------|
| Core Infrastructure (VNet, AKS, APIM, Foundry) | Terraform platform state |
| Per-Team Resources (APIM Products, Foundry Projects, K8s Secrets) | Terraform tenant-access state |
| KAITO Workspaces | Helm chart (optional, for OSS model hosting) |
| ArgoCD | **Removed** |
| Azure Service Operator | **Removed** |

