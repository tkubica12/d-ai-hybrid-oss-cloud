# Networking outputs
output "vnet_id" {
  value       = module.networking.vnet_id
  description = "ID of virtual network"
}

output "subnet_ids" {
  value       = module.networking.subnet_ids
  description = "Map of subnet name to ID"
}

output "nat_gateway_id" {
  value       = module.networking.nat_gateway_id
  description = "ID of NAT gateway"
}

output "bastion_id" {
  value       = module.networking.bastion_id
  description = "ID of Bastion host if created"
}

output "private_dns_zone_ids" {
  value       = module.networking.private_dns_zone_ids
  description = "Map of private DNS zone key to resource ID"
}

# AI Platform outputs
output "apim_name" {
  value       = module.ai_platform.apim_name
  description = "Name of the APIM instance"
}

output "apim_id" {
  value       = module.ai_platform.apim_id
  description = "Resource ID of the APIM instance"
}

output "apim_gateway_url" {
  value       = module.ai_platform.apim_gateway_url
  description = "Gateway URL of the APIM instance"
}

output "foundry_name" {
  value       = module.ai_platform.foundry_name
  description = "Name of the Foundry resource"
}

output "foundry_id" {
  value       = module.ai_platform.foundry_id
  description = "Resource ID of the Foundry resource"
}

output "foundry_endpoint" {
  value       = module.ai_platform.foundry_endpoint
  description = "Endpoint of the Foundry resource"
}

output "openai_api_name" {
  value       = module.ai_platform.openai_api_name
  description = "Name of the OpenAI API in APIM"
}

# AKS outputs for tenant-access module
output "aks_name" {
  value       = module.aks_kaito.aks_name
  description = "Name of the AKS cluster"
}

output "aks_id" {
  value       = module.aks_kaito.aks_id
  description = "Resource ID of the AKS cluster"
}

output "aks_oidc_issuer_url" {
  value       = module.aks_kaito.aks_oidc_issuer_url
  description = "OIDC issuer URL for workload identity"
}

output "aks_host" {
  value       = "https://${module.aks_kaito.aks_name}-dns-${replace(var.subscription_id, "-", "")}.hcp.${var.location}.azmk8s.io:443"
  description = "AKS API server host (computed)"
}

# Resource group info for tenant-access
output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Name of the resource group"
}

output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "ID of the resource group"
}

output "subscription_id" {
  value       = var.subscription_id
  description = "Azure subscription ID"
}

output "location" {
  value       = var.location
  description = "Azure region"
}

# KAITO outputs
output "kaito_helm_release" {
  value       = module.kaito.helm_release_name
  description = "KAITO Helm release name"
}

output "kaito_service_dns_names" {
  value       = module.kaito.service_dns_names
  description = "Map of KAITO model name to internal Kubernetes DNS name"
}
