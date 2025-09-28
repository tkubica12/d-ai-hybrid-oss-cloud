locals {
  aso_controller_values = yamlencode({
    azureSubscriptionID     = data.azurerm_subscription.current.subscription_id
    azureTenantID           = data.azurerm_client_config.current.tenant_id
    azureClientID           = azurerm_user_assigned_identity.aso.client_id
    useWorkloadIdentityAuth = true
    crdPattern              = var.aso_crd_pattern
    asoChartVersion         = var.aso_chart_version
    serviceAccount = {
      annotations = {
        "azure.workload.identity/client-id" = azurerm_user_assigned_identity.aso.client_id
        "azure.workload.identity/use"       = "true"
      }
    }
  })

  aso_configmap_manifest = trimspace(yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = local.aso_configmap_name
      namespace = local.argocd_namespace
    }
    data = {
      (local.aso_configmap_key) = local.aso_controller_values
    }
  }))
}

resource "azapi_resource_action" "argocd_bootstrap" {
  count = local.argocd_bootstrap_enabled ? 1 : 0

  type        = "Microsoft.ContainerService/managedClusters@2025-07-01"
  resource_id = azapi_resource.aks.id
  action      = "runCommand"
  method      = "POST"

  body = {
    command = join(
      "\n",
      [
        format(
          "kubectl create namespace %s --dry-run=client -o yaml | kubectl apply -f -",
          local.argocd_namespace
        ),
        "kubectl apply -f - <<'EOF'",
        local.aso_configmap_manifest,
        "EOF",
        format("kubectl apply -f %s", var.argocd_bootstrap_manifest_url)
      ]
    )
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
