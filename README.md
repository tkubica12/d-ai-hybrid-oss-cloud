# d-ai-hybrid-oss-cloud

Hybrid AI platform combining Azure AI Foundry with open-source models via KAITO on AKS.

## Directory Structure

```
/platform                           # Platform infrastructure
├── /config                         # Platform configuration
│   └── model_catalog.yaml          # KAITO & Foundry model definitions
├── /terraform                      # Platform Terraform (single layer with modules)
│   ├── main.tf, providers.tf, etc. # Main terraform configuration
│   └── /modules                    # Infrastructure modules
│       ├── ai-platform/            # APIM + Foundry resources
│       ├── aks-kaito/              # AKS with KAITO operator
│       ├── kaito/                  # KAITO workspaces & LoadBalancers
│       ├── monitoring/             # Log Analytics, Prometheus, Grafana
│       └── networking/             # VNet, subnets, NAT, DNS
└── /runtime                        # Runtime outputs (auto-generated)
    └── platform-runtime.yaml       # Platform state for tenant-access

/tenant-access                      # Tenant provisioning
├── /config                         # Team access configurations
│   ├── team-alpha/access.yaml      # Team Alpha model access
│   └── team-beta/access.yaml       # Team Beta model access
└── /terraform                      # Tenant Terraform
    └── *.tf                        # APIM products, subscriptions, Foundry projects
```

## Quick Start

### Deploy Platform

**First time deployment (AKS doesn't exist yet):**
```bash
cd platform/terraform
terraform init

# Stage 1: Create AKS cluster first (Helm provider needs AKS to exist)
terraform apply -target=module.aks_kaito

# Stage 2: Deploy Helm charts and remaining resources
terraform apply
```

**Subsequent deployments (AKS already exists):**
```bash
cd platform/terraform
terraform apply
```

### Deploy Tenant Access

```bash
cd tenant-access/terraform
terraform init
terraform apply
```

## Configuration

### Model Catalog (`platform/config/model_catalog.yaml`)

Defines which models are deployed:
- **kaito_models**: OSS models deployed via KAITO on AKS
- **foundry_models**: Azure AI models deployed via Foundry

Set `enabled: true` to deploy a model.

### Team Access (`tenant-access/config/<team>/access.yaml`)

Each team defines their model access and quotas. See [tenant-access/config/README.md](tenant-access/config/README.md) for details.
