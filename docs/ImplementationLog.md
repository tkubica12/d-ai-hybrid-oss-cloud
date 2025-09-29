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

Returned Envoy Gateway to the upstream distribution now that the repo-server can pull OCI charts directly:
- Removed the vendored `charts/gateway-helm` directory in favor of referencing the public `oci://registry-1.docker.io/envoyproxy/gateway-helm` chart at `v1.5.1`.
- Updated the Argo CD application to a multi-source definition that combines the upstream chart with Git-tracked overrides in `argocd/values/envoy-gateway.yaml`.
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
