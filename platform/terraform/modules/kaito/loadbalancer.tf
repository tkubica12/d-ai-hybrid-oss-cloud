# LoadBalancer services are now deployed via the Helm chart (templates/loadbalancer.yaml)
# This file contains only data retrieval for the LoadBalancer IPs after deployment

# NOTE: LoadBalancer IPs are not immediately available after helm_release completes.
# They will be populated asynchronously by the Azure cloud controller.
# For APIM backend configuration, use the AKS internal DNS or wait for LB IPs.

locals {
  # Model names for reference
  model_names = keys(var.enabled_models)
}
