variable "prefix" {
  description = "Prefix for all resources"
  type        = string
  default     = "hai"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "swedencentral"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}
