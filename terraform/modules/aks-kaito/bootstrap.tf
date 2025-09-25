resource "azapi_resource_action" "argocd_bootstrap" {
  count = local.argocd_bootstrap_enabled ? 1 : 0

  type        = "Microsoft.ContainerService/managedClusters@2025-07-01"
  resource_id = azapi_resource.aks.id
  action      = "runCommand"
  method      = "POST"

  body = {
    command = format("kubectl apply -f %s", var.argocd_bootstrap_manifest_url)
  }

  response_export_values = [
    "properties.provisioningState",
    "properties.exitCode",
    "properties.logs"
  ]

  depends_on = [
    azapi_resource.argocd_extension
  ]
}
