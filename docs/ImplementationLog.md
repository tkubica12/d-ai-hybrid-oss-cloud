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
