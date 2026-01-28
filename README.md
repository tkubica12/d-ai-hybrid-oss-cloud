# Hybrid AI Platform

Unified AI gateway combining **Azure AI Foundry** (models as a service) with **open-source models via KAITO** on AKS, all governed through Azure API Management. This demo can easily be extended to on-premises models deployed on Kubernetes using KAITO.

## What It Does

- **Unified Access**: Single APIM endpoint for both Azure AI and open-source models
- **GitOps Self-Service**: Teams request model access via YAML, get API keys after approval
- **Centralized Governance**: Token quotas, rate limits, and cost tracking via APIM policies
- **Shared GPU Resources**: Platform-managed KAITO models, no per-team GPU waste

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PLATFORM (deployed once)                        │
│  ┌──────────────┐   ┌──────────────┐   ┌─────────────────────────────┐  │
│  │ Azure AI     │   │ Azure API    │   │ AKS + KAITO                 │  │
│  │ Foundry      │◄──┤ Management   │──►│ (OSS Models)                │  │
│  │ (GPT-4/5)    │   │ (AI Gateway) │   │ phi-4, mistral, llama, etc. │  │
│  └──────────────┘   └──────────────┘   └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
            ┌──────────────┐        ┌──────────────┐
            │ Team Alpha   │        │ Team Beta    │
            │ • API key    │        │ • API key    │
            │ • Token quota│        │ • Token quota│
            └──────────────┘        └──────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| **AKS + KAITO** | Kubernetes cluster with KAITO operator for OSS model deployment |
| **Azure AI Foundry** | Commercial AI models (GPT-4, GPT-5) with playground & tracing |
| **Azure API Management** | Unified gateway with auth, quotas, and routing |
| **Helm Charts** | KAITO workspace and LoadBalancer deployment |

## GitOps Workflow

1. **Platform team** deploys infrastructure and enables models in `platform/config/model_catalog.yaml`
2. **Dev teams** request access by creating `tenant-access/config/{team}/access.yaml`:
   ```yaml
   team:
     name: alpha
     owner: alpha-lead@contoso.com
   models:
     foundry:
       - name: gpt-4.1
         tokensPerMinute: 10000
     kaito:
       - name: phi-4
         tokensPerMinute: 50000
   ```
3. **PR merged** → run tenant-access terraform → team gets APIM subscription keys
4. **Teams call models** via unified APIM endpoint with their API key

## Directory Structure

```
platform/                    # Infrastructure (deployed by platform team)
├── config/model_catalog.yaml   # Available models
├── terraform/                  # AKS, KAITO, Foundry, APIM
└── runtime/platform-runtime.yaml  # Output for tenant-access

tenant-access/               # Team provisioning (GitOps self-service)
├── config/{team}/access.yaml   # Team model requests
└── terraform/                  # APIM products & subscriptions

charts/kaito-models/         # Helm chart for KAITO workspaces
demo/                        # Test client for API access
```

## Quick Start

### Deploy Platform
```bash
cd platform/terraform
terraform init
terraform apply -target=module.aks_kaito   # First: create AKS
terraform apply                             # Then: deploy everything
```

### Provision Team Access
```bash
cd tenant-access/terraform
terraform apply
```

### Test API Access
```bash
cd demo
cp config.example.yml config.yaml  # Edit with your APIM URL + key
uv run python main.py
```
