variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "base_name" { type = string }
variable "subnet_id_node" { type = string }
variable "subnet_id_api" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "monitor_workspace_id" { type = string }
variable "virtual_network_id" { type = string }
variable "resource_group_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

