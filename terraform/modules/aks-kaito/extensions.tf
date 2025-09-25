resource "azapi_resource" "argocd_extension" {
  type      = "Microsoft.KubernetesConfiguration/extensions@2023-05-01"
  name      = local.argocd_extension_name
  parent_id = azapi_resource.aks.id

  body = {
    properties = {
      extensionType           = local.argocd_extension_type
      autoUpgradeMinorVersion = var.argocd_auto_upgrade
      releaseTrain            = var.argocd_train
      version                 = var.argocd_version
      configurationSettings = {
        "targetNamespace"                                                = local.argocd_namespace
        "deployWithHighAvailability"                                     = var.argocd_ha ? "true" : "false"
        "namespaceInstall"                                               = "false"
        "config-maps.argocd-cmd-params-cm.data.application\\.namespaces" = join(",", local.argocd_application_namespaces)
      }
    }
  }

  depends_on = [
    azapi_resource.aks
  ]
}
