# KAITO Workspaces deployed via Helm
# Uses hashicorp/helm provider which does NOT require cluster connection during plan,
# solving the chicken-and-egg problem when creating AKS and deploying CRDs in same apply.

resource "helm_release" "kaito_models" {
  # Only deploy if there are enabled models
  count = length(var.enabled_models) > 0 ? 1 : 0

  name             = "kaito-models"
  chart            = "${path.module}/../../../../charts/kaito-models"
  namespace        = "default"
  create_namespace = false

  # Allow upgrading existing release
  upgrade_install = true

  # Timeout for GPU provisioning (KAITO can take time to provision nodes)
  timeout = 1800 # 30 minutes

  # Pass enabled models as values with static IP configuration
  values = [
    yamlencode({
      models = {
        for name, model in var.enabled_models : name => {
          enabled      = true
          preset       = model.preset
          instanceType = model.instanceType
          staticIP     = var.model_ips[name]
        }
      }
      loadbalancer = {
        internal      = true
        aksSubnetName = var.aks_subnet_name
      }
    })
  ]

  # Wait for resources to be ready
  wait = true
}

# DNS names are pre-defined based on model name
# LoadBalancer IPs are statically assigned via annotations
# No need to query Kubernetes for IPs at terraform time
