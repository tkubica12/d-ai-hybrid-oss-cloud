locals {
  subnets = {
    aks = {
      address_prefix = cidrsubnet(var.vnet_cidr, 8, 0)
    }
    aks-api = {
      address_prefix = cidrsubnet(var.vnet_cidr, 8, 1)
      delegation = {
        service = "Microsoft.ContainerService/managedClusters"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ]
      }
    }
    onprem = {
      address_prefix = cidrsubnet(var.vnet_cidr, 8, 2)
    }
    private-endpoint = {
      address_prefix = cidrsubnet(var.vnet_cidr, 8, 3)
    }
    AzureBastionSubnet = {
      address_prefix = cidrsubnet(var.vnet_cidr, 8, 4)
    }
    jump = {
      address_prefix = cidrsubnet(var.vnet_cidr, 8, 5)
    }
    api-management = {
      address_prefix = cidrsubnet(var.vnet_cidr, 8, 6)
    }
  }

  private_dns_zones = {
    acr  = "privatelink.azurecr.io"
    blob = "privatelink.blob.core.windows.net"
  }
}