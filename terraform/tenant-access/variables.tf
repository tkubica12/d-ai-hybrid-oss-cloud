variable "platform_state_path" {
  description = "Path to the platform Terraform state file"
  type        = string
  default     = "../platform/terraform.tfstate"
}

variable "developer_requests_path" {
  description = "Path to the developer-requests directory containing team access YAML files"
  type        = string
  default     = "../../developer-requests"
}
