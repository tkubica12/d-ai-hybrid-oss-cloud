output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "ID of the created Virtual Network"
}

output "subnet_ids" {
  value       = { for k, v in azurerm_subnet.subs : k => v.id }
  description = "Map of subnet name to subnet ID"
}

output "nat_gateway_id" {
  value       = azurerm_nat_gateway.main.id
  description = "ID of NAT Gateway"
}

output "bastion_id" {
  value       = azurerm_bastion_host.main.id
  description = "ID of Bastion host"
}

output "private_dns_zone_ids" {
  value       = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
  description = "Map of DNS zone key to zone resource ID"
}