# Tenant Access Configuration

This folder contains team-level access requests for AI models. Each subfolder represents a team and contains their access configuration.

## How to Request Access

1. Create a new folder with your team name: `tenant-access/config/{team-name}/`
2. Create an `access.yaml` file based on the example below
3. Submit a Pull Request for review
4. Once merged, run tenant-access terraform to provision your access

## Example Request

```yaml
# tenant-access/config/team-alpha/access.yaml
team:
  name: alpha
  displayName: "AI Access - Team Alpha"
  owner: alpha-lead@contoso.com
  costCenter: CC-12345

models:
  foundry:
    - name: gpt-4.1
      tokensPerMinute: 10000
      dailyTokenQuota: 1000000
  kaito:
    - name: phi-4
      tokensPerMinute: 50000
      dailyTokenQuota: 5000000
```

## What Gets Created

When your request is merged, the following resources are provisioned:

### For Foundry Models:
- **APIM Product**: Container for your API access
- **APIM ProductPolicy**: Token-based rate limits and daily quotas (using `llm-token-limit` policy)
- **APIM Subscription**: API keys for authentication

### For KAITO Models (if enabled in platform catalog):
- All the above APIM resources for unified access to shared GPU workloads

## Modifying Your Access

Simply update your `access.yaml` and run terraform apply. Changes to limits, models, or other settings will be automatically applied.

## Deleting Your Access

Remove your team folder and run terraform apply. All associated resources will be cleaned up.
