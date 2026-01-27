# NOTE: LoadBalancer IPs are populated asynchronously by Azure after helm_release completes.
# For immediate APIM backend configuration, use Kubernetes internal DNS names:
#   kaito-lb-<model-name>.default.svc.cluster.local

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = length(helm_release.kaito_models) > 0 ? helm_release.kaito_models[0].name : null
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = length(helm_release.kaito_models) > 0 ? helm_release.kaito_models[0].status : null
}

output "workspace_names" {
  description = "Map of model name to workspace name"
  value = {
    for name, model in var.enabled_models :
    name => "workspace-${name}"
  }
}

output "service_dns_names" {
  description = "Map of model name to internal Kubernetes DNS name for the LoadBalancer service"
  value = {
    for name, model in var.enabled_models :
    name => "kaito-lb-${name}.default.svc.cluster.local"
  }
}
