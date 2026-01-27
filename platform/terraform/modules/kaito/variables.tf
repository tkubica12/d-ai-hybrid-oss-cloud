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

# Kubernetes connection credentials
variable "kube_host" {
  description = "Kubernetes API server host"
  type        = string
  sensitive   = true
}

variable "kube_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "kube_client_certificate" {
  description = "Kubernetes client certificate (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "kube_client_key" {
  description = "Kubernetes client key (base64 encoded)"
  type        = string
  sensitive   = true
}
