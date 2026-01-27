# KAITO Models Helm Chart

This Helm chart deploys KAITO Workspace CRDs and internal LoadBalancer services for OSS AI models.

## Overview

The chart creates:
- **KAITO Workspace CRDs**: Custom resources that trigger the KAITO operator to provision GPU nodes and deploy model inference pods
- **LoadBalancer Services**: Internal Azure LoadBalancers that expose models to APIM

## Usage

The chart is deployed via Terraform using the `helm_release` resource. Values are passed from the model catalog configuration.

### Manual Testing

```bash
# Dry run to see rendered templates
helm template kaito-models ./charts/kaito-models \
  --set models.mistral-7b.enabled=true \
  --set models.mistral-7b.preset=mistral-7b-instruct \
  --set models.mistral-7b.instanceType=Standard_NC24ads_A100_v4

# Install to cluster
helm install kaito-models ./charts/kaito-models -f values.yaml
```

## Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `models` | Map of model configurations | `{}` |
| `models.<name>.enabled` | Whether to deploy this model | `false` |
| `models.<name>.preset` | KAITO preset name | - |
| `models.<name>.instanceType` | Azure VM size for GPU nodes | - |
| `namespace` | Namespace for all resources | `default` |
| `loadbalancer.internal` | Use Azure internal LB | `true` |
| `loadbalancer.port` | Service port | `80` |
| `loadbalancer.targetPort` | Pod port (vLLM default) | `5000` |

## Architecture

```
APIM → Internal LoadBalancer → KAITO Workspace Pod (GPU node)
```

The KAITO operator handles:
1. GPU node provisioning via Karpenter
2. Model download and caching
3. vLLM inference server deployment
4. Health checks and scaling
