resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "subs" {
  for_each                        = local.subnets
  name                            = each.key
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [each.value.address_prefix]
  default_outbound_access_enabled = false

  dynamic "delegation" {
    for_each = try([each.value.delegation], [])
    content {
      name = "delegation"
      service_delegation {
        name    = delegation.value.service
        actions = delegation.value.actions
      }
    }
  }
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${var.base_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                = "ngw-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_network_security_group" "subnet" {
  for_each            = { for k, v in azurerm_subnet.subs : k => v if k != "AzureBastionSubnet" }
  name                = "nsg-${each.key}-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "subnet" {
  for_each                  = azurerm_network_security_group.subnet
  subnet_id                 = azurerm_subnet.subs[each.key].id
  network_security_group_id = each.value.id
}

resource "azurerm_subnet_nat_gateway_association" "subs" {
  for_each       = { for k, v in azurerm_subnet.subs : k => v if k != "AzureBastionSubnet" }
  subnet_id      = each.value.id
  nat_gateway_id = azurerm_nat_gateway.main.id
  depends_on = [
    azurerm_nat_gateway_public_ip_association.main,
    azurerm_subnet_network_security_group_association.subnet
  ]
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.base_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "bastion-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subs["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
  depends_on = [azurerm_subnet.subs]
  tags       = var.tags
}
