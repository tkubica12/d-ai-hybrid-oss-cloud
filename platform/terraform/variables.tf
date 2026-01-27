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

variable "model_catalog_path" {
  description = "Path to the model catalog YAML file"
  type        = string
  default     = "../config/model_catalog.yaml"
}

variable "runtime_output_path" {
  description = "Path to output the platform runtime YAML file"
  type        = string
  default     = "../runtime/platform-runtime.yaml"
}
