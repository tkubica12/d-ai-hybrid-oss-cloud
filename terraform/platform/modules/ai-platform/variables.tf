variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "ID of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "base_name" {
  description = "Base name for resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "apim_publisher_email" {
  description = "Publisher email for APIM"
  type        = string
  default     = "admin@contoso.com"
}

variable "apim_publisher_name" {
  description = "Publisher name for APIM"
  type        = string
  default     = "AI Platform Team"
}

variable "foundry_models" {
  description = "List of AI models to deploy in Foundry"
  type = list(object({
    name       = string
    model_name = string
    version    = string
    sku_name   = string
    capacity   = number
  }))
  default = []
}
