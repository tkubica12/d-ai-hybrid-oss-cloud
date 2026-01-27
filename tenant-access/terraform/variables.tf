variable "platform_state_path" {
  description = "Path to the platform Terraform state file"
  type        = string
  default     = "../../platform/terraform/terraform.tfstate"
}

variable "platform_runtime_path" {
  description = "Path to the platform runtime YAML file"
  type        = string
  default     = "../../platform/runtime/platform-runtime.yaml"
}

variable "tenant_config_path" {
  description = "Path to the tenant configuration directory containing team access YAML files"
  type        = string
  default     = "../config"
}
