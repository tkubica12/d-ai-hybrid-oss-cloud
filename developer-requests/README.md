# Developer Requests

This folder contains team-level access requests for AI models. Each subfolder represents a team and contains their access configuration.

## How to Request Access

1. Create a new folder with your team name: `developer-requests/{team-name}/`
2. Create an `access.yaml` file based on the example below
3. Submit a Pull Request for review
4. Once merged, ArgoCD will automatically provision your access

## Example Request

```yaml
# developer-requests/team-alpha/access.yaml
team:
  name: alpha
  displayName: "AI Access - Team Alpha"
  owner: alpha-lead@contoso.com
  costCenter: CC-12345

models:
  foundry:
    enabled: true
    models:
      - gpt-4o
  kaito:
    enabled: false

limits:
  tokensPerMinute: 5000
  dailyTokenQuota: 1000000
```

## What Gets Created

When your request is merged, the following resources are provisioned:

### For Foundry Models:
- **APIM Product**: Container for your API access
- **APIM ProductPolicy**: Token-based rate limits and daily quotas (using `llm-token-limit` policy)
- **APIM Subscription**: API keys for authentication
- **Kubernetes Secret**: Contains your API keys (`{team-name}-api-key`)

> **Note**: Foundry Projects for Playground access are not yet supported via GitOps. 
> Projects must be created manually via Azure Portal or CLI until Azure Service Operator adds support.

### For KAITO Models (if enabled):
- **KAITO Workspace**: Dedicated GPU compute for the model
- All the above APIM resources for unified access

## Retrieving Your API Key

After your request is provisioned:

```bash
# Get your primary API key
kubectl get secret {team-name}-api-key -n developer-requests -o jsonpath='{.data.primary-key}' | base64 -d

# Use with the AI Gateway endpoint (update with your APIM name)
curl https://apim-hai-twej.azure-api.net/openai/deployments/gpt-4o/chat/completions \
  -H "Content-Type: application/json" \
  -H "api-key: YOUR_API_KEY" \
  -d '{"messages": [{"role": "user", "content": "Hello!"}]}'
```

## Modifying Your Access

Simply update your `access.yaml` and submit a PR. Changes to limits, models, or other settings will be automatically applied after merge.

## Deleting Your Access

Remove your team folder and submit a PR. ArgoCD will automatically clean up all associated resources.

## Architecture

```
Platform Team (Terraform)           Developer Self-Service (GitOps)
┌────────────────────────────┐      ┌─────────────────────────────────┐
│ APIM v2 Standard           │◄────►│ APIM Products per team          │
│ Foundry Resource           │◄────►│ Foundry Projects per team       │
│ Model Deployments          │      │ APIM Subscriptions (API keys)   │
│ APIM API + Backend         │      │ KAITO Workspaces (OSS models)   │
└────────────────────────────┘      └─────────────────────────────────┘
```
