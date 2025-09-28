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

variable "argocd_version" {
  type        = string
  description = <<-EOT
	Version of the Microsoft ArgoCD extension to deploy.
	Must match a preview or GA build published for the Azure GitOps service.
	Example: "0.0.7-preview".
	EOT
  default     = "0.0.7-preview"
}

variable "argocd_train" {
  type        = string
  description = <<-EOT
	Release train for the Microsoft ArgoCD extension update channel.
	Accepted values include "stable" and "preview" depending on feature needs.
	Example: "preview".
	EOT
  default     = "preview"
}

variable "argocd_auto_upgrade" {
  type        = bool
  description = <<-EOT
	Enables automatic minor version upgrades for the ArgoCD extension.
	Set to true to let Azure handle rolling updates, or false to keep manual control.
	Example: false.
	EOT
  default     = false
}

variable "argocd_ha" {
  type        = bool
  description = <<-EOT
	Controls whether the ArgoCD extension deploys in high availability mode.
	Requires at least three nodes in the cluster when true.
	Example: false.
	EOT
  default     = false
}

variable "argocd_bootstrap_manifest_url" {
  type        = string
  description = <<-EOT
	Location of the Argo CD bootstrap manifest applied via the AKS run command.
	Use a raw HTTPS URL that resolves to an Argo CD Application definition (app-of-apps).
	Set to an empty string to skip automated bootstrap.
	Example: "https://raw.githubusercontent.com/tkubica12/d-ai-hybrid-oss-cloud/main/argocd/bootstrap-application.yaml".
	EOT
  default     = "https://raw.githubusercontent.com/tkubica12/d-ai-hybrid-oss-cloud/main/argocd/bootstrap-application.yaml"
}

variable "aso_crd_pattern" {
  type        = string
  description = <<-EOT
	Semicolon-separated pattern controlling which Azure Service Operator v2 CRDs are installed.
	Each entry follows the "<group>/<kind>" glob match used by ASO; include entire groups to keep dependencies intact.
	Example: "resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*".
	EOT
	default     = "resources.azure.com/*;cognitiveservices.azure.com/*;apimanagement.azure.com/*;managedidentity.azure.com/*;keyvault.azure.com/*"
}

variable "aso_chart_version" {
  type        = string
  description = <<-EOT
	Helm chart version for Azure Service Operator v2 used by the Argo CD application.
	Must correspond to a published package in the https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts repository.
	Example: "2.15.0".
	EOT
  default     = "2.15.0"
}

