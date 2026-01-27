# KAITO module outputs including LoadBalancer IPs for APIM VNet-integrated access

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
  description = "Map of model name to private DNS name for the LoadBalancer service"
  value = {
    for name, model in var.enabled_models :
    name => "${name}.${var.dns_zone_name}"
  }
}

output "service_ips" {
  description = "Map of model name to static internal LoadBalancer IP address"
  value = var.model_ips
}
