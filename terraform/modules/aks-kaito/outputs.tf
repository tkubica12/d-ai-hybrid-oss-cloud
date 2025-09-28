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

output "aso_managed_identity_id" {
  value = azurerm_user_assigned_identity.aso.id
}

output "aso_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.aso.client_id
}

output "aso_managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.aso.principal_id
}

output "aso_workload_identity_subject" {
  value = local.aso_service_account_subject
}

output "aks_oidc_issuer_url" {
  value = try(jsondecode(azapi_resource.aks.output).properties.oidcIssuerProfile.issuerURL, null)
}
