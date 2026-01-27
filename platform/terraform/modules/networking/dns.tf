resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = azurerm_private_dns_zone.zones
  name                  = "lnk-${each.key}-${var.base_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# DNS A records for KAITO model endpoints
# Creates predictable DNS names like: mistral-7b.kaito.internal
resource "azurerm_private_dns_a_record" "kaito_models" {
  for_each            = var.kaito_model_ips
  name                = each.key
  zone_name           = azurerm_private_dns_zone.zones["kaito"].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [each.value]
  tags                = var.tags
}