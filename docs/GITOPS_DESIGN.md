# GitOps Design for AI Model Self-Service

## Overview

This document outlines the architecture and implementation plan for a GitOps-based self-service system that allows developers to request access to AI models (both Azure AI Foundry models and open-source models via KAITO) through declarative YAML definitions.

## Goals

1. **Developer Self-Service**: Developers request model access via YAML files in Git
2. **GitOps Workflow**: Approval via PR merge, desired state reconciliation
3. **Unified Experience**: Same request structure for Foundry and KAITO models
4. **Centralized Governance**: Token limits, quotas, and access control via Azure API Management
5. **Full Foundry Experience**: Playground, tracing, and portal access for Foundry models
6. **Lifecycle Management**: Create, update, and delete access through Git operations

## Architecture

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                            PLATFORM LAYER (Terraform)                          │
│                         Deployed once by Platform Team                          │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────┐ │
│  │  Foundry Resource   │  │   APIM Instance     │  │    AKS + KAITO          │ │
│  │  (AIServices)       │  │   (AI Gateway)      │  │    (OSS Models)         │ │
│  │                     │  │                     │  │                         │ │
│  │  Centralized Model  │  │  • API definitions  │  │  • Node Auto Provision  │ │
│  │  Deployments:       │◄─┤  • Global policies  │──┤  • KAITO operator       │ │
│  │  - gpt-4.1          │  │  • Backends config  │  │  • GPU node pools       │ │
│  │  - gpt-5.2          │  │                     │  │                         │ │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────────┘ │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                       GITOPS LAYER (ArgoCD + ASO + KAITO)                      │
│                    Developer requests processed automatically                   │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  developer-requests/                 ArgoCD ApplicationSet                      │
│  ├── team-alpha/        ──────────►  watches this folder and                   │
│  │   └── access.yaml                 generates resources via                   │
│  ├── team-beta/                      developer-access Helm chart               │
│  │   └── access.yaml                                                           │
│                                                                                │
│  Generated Resources (per team):                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ For Foundry Models:                                                     │   │
│  │  • Foundry Project (ASO: cognitiveservices.azure.com/Account)           │   │
│  │  • APIM Product (ASO: apimanagement.azure.com/Product)                  │   │
│  │  • APIM ProductPolicy (token limits)                                    │   │
│  │  • APIM Subscription (API key generation)                               │   │
│  │  • RBAC Assignment (Azure AI User role)                                 │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ For KAITO/OSS Models:                                                   │   │
│  │  • KAITO Workspace (kaito.sh/v1beta1)                                   │   │
│  │  • APIM Product (same structure as Foundry)                             │   │
│  │  • APIM ProductPolicy (token limits)                                    │   │
│  │  • APIM Subscription (API key generation)                               │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

## Key Decisions

### 1. Model Deployment Strategy

| Model Type | Deployment Location | Sharing Model |
|------------|---------------------|---------------|
| Foundry Models (gpt-4.1, gpt-5.2) | Foundry Resource level | Shared by all projects |
| KAITO Models (phi-4, mistral) | Per-workspace in AKS | Dedicated per team request |

**Rationale**: Foundry models are pay-per-token, so sharing is cost-effective. KAITO models require dedicated GPU compute, so each team gets their own workspace.

### 2. Access Control via APIM

All model access flows through Azure API Management:
- **Subscription Keys**: Each team gets unique API keys
- **Token Limits**: Per-minute (TPM) rate limiting via `llm-token-limit` policy
- **Quotas**: Daily/monthly token quotas via `quota-by-key` policy
- **Unified Endpoint**: Single APIM endpoint for all models

### 3. Foundry Portal Access

Foundry Projects are created per-team, enabling:
- ✅ Playground access in Foundry Portal
- ✅ Tracing via Application Insights
- ✅ Evaluations and testing
- ✅ Access to shared model deployments

### 4. KAITO Model Access

KAITO workspaces provide:
- ✅ Dedicated GPU compute per team
- ✅ OpenAI-compatible API endpoint
- ❌ No native portal (API-only, or custom UI)

### 5. Authentication Strategy

**Phase 1 (Current)**: API Keys via APIM Subscriptions
- Simple to implement
- Keys stored in Kubernetes Secrets
- Teams retrieve keys from designated location

**Phase 2 (Future)**: Managed Identity
- Workload identity for applications
- Entra ID for developers
- No secrets to manage

## Implementation Plan

### Phase 1: Platform Infrastructure (Terraform)

- [x] AKS cluster with KAITO
- [x] Foundry Resource (Account)
- [ ] APIM instance with AI Gateway configuration
- [ ] Foundry model deployments (gpt-4.1, etc.)
- [ ] APIM backends (Foundry + KAITO)
- [ ] APIM API definitions

### Phase 2: GitOps Foundation (ArgoCD)

- [ ] Azure Service Operator CRD patterns for:
  - `cognitiveservices.azure.com/*`
  - `apimanagement.azure.com/*`
- [ ] ArgoCD ApplicationSet for developer-requests folder
- [ ] Base Helm chart for developer-access

### Phase 3: Developer Access Chart

- [ ] Helm chart: `charts/developer-access/`
- [ ] Template: Foundry Project creation
- [ ] Template: APIM Product per team
- [ ] Template: APIM ProductPolicy with token limits
- [ ] Template: APIM Subscription with secret export
- [ ] Template: KAITO Workspace (conditional)

### Phase 4: Developer Request Schema

- [ ] Define YAML schema for requests
- [ ] Create example requests
- [ ] Document request process

### Phase 5: Testing & Validation

- [ ] Test Foundry Playground access via project
- [ ] Test APIM token limits enforcement
- [ ] Test KAITO workspace creation
- [ ] Test API key retrieval
- [ ] End-to-end flow validation

## Developer Request Schema

```yaml
# developer-requests/{team-name}/access.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {team-name}-access-request
  labels:
    app.kubernetes.io/managed-by: gitops
    ai.contoso.com/request-type: model-access
data:
  # Team metadata
  team: "{team-name}"
  owner: "{owner-email}"
  costCenter: "{cost-center}"
  
  # Model requests (YAML-encoded list)
  models: |
    - name: gpt-4.1
      type: foundry
      enabled: true
    - name: phi-4
      type: kaito
      enabled: true
      instanceType: Standard_NC24ads_A100_v4
  
  # Token limits
  tokensPerMinute: "5000"
  dailyTokenQuota: "1000000"
  
  # Features
  playgroundAccess: "true"
  tracingEnabled: "true"
```

## Folder Structure

```
charts/
├── foundry/                    # Foundry Account (existing)
├── foundry-models/             # Centralized model deployments
├── ai-gateway/                 # APIM instance and configuration
├── models/                     # KAITO workspaces (existing)
└── developer-access/           # Per-team access provisioning

developer-requests/             # GitOps request folder
├── team-alpha/
│   └── access.yaml
├── team-beta/
│   └── access.yaml
└── README.md

argocd/
├── apps/
│   └── developer-access.yaml   # ApplicationSet for requests
└── values/
```

## Security Considerations

1. **RBAC**: Developers get minimal Azure AI User role on their project only
2. **Network**: APIM can enforce private endpoints if required
3. **Secrets**: API keys stored in Kubernetes Secrets with RBAC
4. **Audit**: All changes tracked in Git history
5. **Approval**: PR review required before merge (GitOps approval flow)

## Monitoring & Observability

1. **APIM Metrics**: Token usage, request counts, latency
2. **Foundry Tracing**: Application Insights integration per project
3. **KAITO Metrics**: Prometheus metrics from AKS
4. **ArgoCD**: Sync status and health monitoring

## Future Enhancements

1. **Managed Identity**: Replace API keys with workload identity
2. **Cost Tracking**: Per-team cost allocation via tags
3. **Auto-scaling**: Dynamic quota adjustment based on usage
4. **Custom Models**: Support for fine-tuned models
5. **Multi-cluster**: Extend to multiple AKS clusters for KAITO
