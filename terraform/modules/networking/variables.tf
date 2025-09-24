variable "resource_group_name" {
	type        = string
	description = <<EOF
Name of the resource group where networking resources will be deployed.
EOF
}

variable "location" {
	type        = string
	description = <<EOF
Azure region for networking resources.
Should match the resource group's location.
EOF
}

variable "base_name" {
	type        = string
	description = <<EOF
Base name (already includes randomness) used for resource naming, passed from root local.base_name.
EOF
}

variable "base_name_nodash" {
	type        = string
	description = <<EOF
Base name without dashes for scenarios requiring alphanumeric (passed from root local.base_name_nodash).
EOF
}

variable "vnet_cidr" {
	type        = string
	default     = "10.10.0.0/16"
	description = <<EOF
Address space (CIDR) for the Virtual Network.
Default provides /16 which will be split into /24 subnets.
EOF
}


variable "tags" {
	type        = map(string)
	default     = {}
	description = <<EOF
Optional tags applied to resources that support tagging.
EOF
}
