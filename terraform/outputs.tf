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
