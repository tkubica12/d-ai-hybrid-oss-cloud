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

output "apim_gateway_url" {
  value       = module.ai_platform.apim_gateway_url
  description = "Gateway URL of the APIM instance"
}

output "foundry_name" {
  value       = module.ai_platform.foundry_name
  description = "Name of the Foundry resource"
}

output "foundry_endpoint" {
  value       = module.ai_platform.foundry_endpoint
  description = "Endpoint of the Foundry resource"
}
