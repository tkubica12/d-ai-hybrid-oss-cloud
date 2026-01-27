output "aks_id" {
  value = azapi_resource.aks.id
}

output "aks_name" {
  value = local.aks_name
}

output "aks_kubelet_identity_object_id" {
  value = null
}

output "aks_principal_id" {
  value = azurerm_user_assigned_identity.aks.principal_id
}

output "ssh_private_key_pem" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

output "aks_oidc_issuer_url" {
  value = try(jsondecode(azapi_resource.aks.output).properties.oidcIssuerProfile.issuerURL, null)
}

# Additional outputs for Kubernetes provider
output "aks_kube_config_host" {
  description = "AKS API server host from kubeconfig"
  value       = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
  sensitive   = true
}

output "aks_cluster_ca_certificate" {
  description = "AKS cluster CA certificate (base64 encoded)"
  value       = data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "aks_client_certificate" {
  description = "AKS client certificate (base64 encoded)"
  value       = data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive   = true
}

output "aks_client_key" {
  description = "AKS client key (base64 encoded)"
  value       = data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key
  sensitive   = true
}

# Data source to get kubeconfig details
data "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  resource_group_name = var.resource_group_name

  depends_on = [azapi_resource.aks]
}
