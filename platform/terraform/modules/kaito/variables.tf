variable "enabled_models" {
  description = "Map of enabled KAITO models from the catalog"
  type = map(object({
    name                     = string
    displayName              = string
    description              = string
    preset                   = string
    instanceType             = string
    enabled                  = bool
    estimatedTokensPerMinute = number
  }))
}

variable "dns_zone_name" {
  description = "Private DNS zone name for KAITO model endpoints (e.g., kaito.internal)"
  type        = string
}

variable "model_ips" {
  description = "Map of model name to static IP address for LoadBalancer"
  type        = map(string)
}

variable "aks_subnet_name" {
  description = "AKS subnet name for internal LoadBalancer annotation (just the name, not full resource ID)"
  type        = string
}

# Helm provider is passed from root module via providers block
